// RV32IM instruction-set simulator with doom_riscv's memory map.
// Counts instruction fetches and data accesses per region, per rendered frame.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

#define ROM_BASE 0x40100000u
#define ROM_SIZE (1u<<20)
#define WAD_BASE 0x50000000u
#define RAM_BASE 0x41000000u
#define RAM_SIZE (8u<<20)
#define BRM_BASE 0x00000000u
#define BRM_SIZE 0x1000u
#define VID_CTRL 0x81000000u
#define VID_PAL  0x81010000u
#define VID_FB   0x81020000u
#define FB_SIZE  64000u
#define UART_BS  0x82000000u
#define LED_BS   0x83000000u
#define VTICK    30000ULL   /* instrs per 1/70s; ~2.1 MIPS assumed */

static uint8_t *rom, *ram, *brm, *wad, *fb;
static size_t wad_size;
static uint32_t pc, x[32];

// counters
static uint64_t n_instr, n_load, n_store;
static uint64_t f_rom, f_ram;                 // instruction fetches by region
static uint64_t d_rom, d_wad, d_ram, d_per;   // data accesses by region
static uint64_t frames;
static uint64_t last_instr, last_load, last_store, last_from, last_fram,
                last_drom, last_dwad, last_dram;
static int max_frames = 12;

/* ---- direct-mapped cache model, 32-byte lines ---- */
static uint32_t ic_lines=1024, dc_lines=1024;   /* *32B = 32 KB each */
static uint32_t *ic_tag, *dc_tag;
static uint64_t ic_hit, ic_miss, dc_hit, dc_miss;
static uint64_t last_ich,last_icm,last_dch,last_dcm;
static inline void cache_acc(uint32_t a, uint32_t *tags, uint32_t nlines,
                             uint64_t *hit, uint64_t *miss) {
    uint32_t line = a >> 5;
    uint32_t idx  = line & (nlines-1);
    uint32_t tag  = line / nlines;
    if (tags[idx] == (tag|0x80000000u)) (*hit)++;
    else { (*miss)++; tags[idx] = tag|0x80000000u; }
}

static inline uint8_t *resolve(uint32_t a, int is_fetch, int sz) {
    if (a >= RAM_BASE && a < RAM_BASE+RAM_SIZE) { if(is_fetch){f_ram++; cache_acc(a,ic_tag,ic_lines,&ic_hit,&ic_miss);} else {d_ram++; cache_acc(a,dc_tag,dc_lines,&dc_hit,&dc_miss);} return ram + (a-RAM_BASE); }
    if (a >= ROM_BASE && a < ROM_BASE+ROM_SIZE) { if(is_fetch){f_rom++; cache_acc(a,ic_tag,ic_lines,&ic_hit,&ic_miss);} else {d_rom++; cache_acc(a,dc_tag,dc_lines,&dc_hit,&dc_miss);} return rom + (a-ROM_BASE); }
    if (a >= WAD_BASE && a < WAD_BASE+wad_size){ d_wad++; return wad + (a-WAD_BASE); }
    if (a >= BRM_BASE && a < BRM_BASE+BRM_SIZE){ if(is_fetch) f_rom++; else d_ram++; return brm + (a-BRM_BASE); }
    return NULL;
}

static void report(const char *tag) {
    uint64_t i=n_instr-last_instr, l=n_load-last_load, s=n_store-last_store;
    printf("%-8s instr=%-10llu Ifetch=%-10llu Dacc=%-9llu | Imiss=%-8llu Dmiss=%-8llu | ",
        tag,(unsigned long long)i,
        (unsigned long long)((f_rom-last_from)+(f_ram-last_fram)),
        (unsigned long long)((d_rom-last_drom)+(d_ram-last_dram)),
        (unsigned long long)(ic_miss-last_icm),(unsigned long long)(dc_miss-last_dcm));
    last_ich=ic_hit; last_icm=ic_miss; last_dch=dc_hit; last_dcm=dc_miss;
    printf("%-2s instr=%-11llu  Ifetch[rom=%-10llu ram=%-9llu]  D[rom=%-8llu wad=%-8llu ram=%-10llu]  ld=%-9llu st=%-9llu\n",
        "",(unsigned long long)i,
        (unsigned long long)(f_rom-last_from),(unsigned long long)(f_ram-last_fram),
        (unsigned long long)(d_rom-last_drom),(unsigned long long)(d_wad-last_dwad),
        (unsigned long long)(d_ram-last_dram),(unsigned long long)l,(unsigned long long)s);
    fflush(stdout);
    last_instr=n_instr; last_load=n_load; last_store=n_store;
    last_from=f_rom; last_fram=f_ram; last_drom=d_rom; last_dwad=d_wad; last_dram=d_ram;
}

static uint32_t load(uint32_t a, int sz, int sext) {
    n_load++;
    if (a >= VID_CTRL && a < VID_CTRL+0x10000) { d_per++; return (uint32_t)((n_instr/VTICK)&0xffff) | (1u<<16); }
    if (a >= UART_BS && a < UART_BS+0x10000)   { d_per++; return 0xffffffffu; }  // no key
    if (a >= VID_FB && a < VID_FB+FB_SIZE)     { d_per++; return 0; }
    if (a >= VID_PAL && a < VID_PAL+0x10000)   { d_per++; return 0; }
    uint8_t *p = resolve(a,0,sz);
    if (!p) { fprintf(stderr,"\n[load fault @%08x pc=%08x]\n",a,pc); exit(1); }
    uint32_t v = sz==1 ? *p : sz==2 ? *(uint16_t*)p : *(uint32_t*)p;
    if (sext) v = sz==1 ? (uint32_t)(int32_t)(int8_t)v : sz==2 ? (uint32_t)(int32_t)(int16_t)v : v;
    return v;
}

static void store(uint32_t a, uint32_t v, int sz) {
    n_store++;
    if (a >= VID_FB && a < VID_FB+FB_SIZE) {
        d_per++;
        if (a == VID_FB) { frames++; char t[16]; snprintf(t,sizeof t,"frame%llu",(unsigned long long)frames); report(t);
                           if (frames >= (uint64_t)max_frames) { printf("\n[done]\n"); exit(0); } }
        return;
    }
    if (a >= UART_BS && a < UART_BS+0x10000) { d_per++; if((a&0xf)==0){ fputc(v&0xff,stderr);} return; }
    if (a >= VID_PAL && a < VID_PAL+0x10000) { d_per++; return; }
    if (a >= VID_CTRL&& a < VID_CTRL+0x10000){ d_per++; return; }
    if (a >= LED_BS  && a < LED_BS+0x10000)  { d_per++; return; }
    uint8_t *p = resolve(a,0,sz);
    if (!p) { fprintf(stderr,"\n[store fault @%08x pc=%08x]\n",a,pc); exit(1); }
    if (sz==1) *p=v; else if (sz==2) *(uint16_t*)p=v; else *(uint32_t*)p=v;
}

int main(int argc, char **argv) {
    if (argc<3) { fprintf(stderr,"usage: iss elf wad [frames]\n"); return 1; }
    if (argc>3) max_frames = atoi(argv[3]);
    if (argc>4) ic_lines = (uint32_t)atoi(argv[4]);
    if (argc>5) dc_lines = (uint32_t)atoi(argv[5]);
    ic_tag=calloc(ic_lines,4); dc_tag=calloc(dc_lines,4);
    fprintf(stderr,"[icache %u KB, dcache %u KB, 32B lines]\n", ic_lines*32/1024, dc_lines*32/1024);
    rom=calloc(1,ROM_SIZE); ram=calloc(1,RAM_SIZE); brm=calloc(1,BRM_SIZE);
    int wf=open(argv[2],O_RDONLY); struct stat st; fstat(wf,&st); wad_size=st.st_size;
    wad=mmap(NULL,wad_size,PROT_READ,MAP_PRIVATE,wf,0);

    // load ELF PT_LOAD segments at their physical (LMA) address
    FILE *f=fopen(argv[1],"rb"); if(!f){perror("elf");return 1;}
    uint8_t eh[52]; fread(eh,1,52,f);
    uint32_t phoff=*(uint32_t*)(eh+28); uint16_t phnum=*(uint16_t*)(eh+44), phes=*(uint16_t*)(eh+42);
    pc=*(uint32_t*)(eh+24);
    for (int i=0;i<phnum;i++){
        uint8_t ph[32]; fseek(f,phoff+i*phes,SEEK_SET); fread(ph,1,32,f);
        uint32_t type=*(uint32_t*)ph, off=*(uint32_t*)(ph+4), paddr=*(uint32_t*)(ph+12), fsz=*(uint32_t*)(ph+16);
        if (type!=1||!fsz) continue;
        uint8_t *p = (paddr>=ROM_BASE&&paddr<ROM_BASE+ROM_SIZE)?rom+(paddr-ROM_BASE)
                   : (paddr>=RAM_BASE&&paddr<RAM_BASE+RAM_SIZE)?ram+(paddr-RAM_BASE)
                   : (paddr<BRM_SIZE)?brm+paddr : NULL;
        if(!p){fprintf(stderr,"seg %08x unmapped\n",paddr);return 1;}
        fseek(f,off,SEEK_SET); fread(p,1,fsz,f);
        fprintf(stderr,"[seg %08x +%u]\n",paddr,fsz);
    }
    fclose(f);
    x[2] = RAM_BASE+RAM_SIZE;   // sp = __stacktop

    for(;;){
        uint8_t *ip = resolve(pc,1,4);
        if(!ip){fprintf(stderr,"\n[fetch fault @%08x]\n",pc);return 1;}
        uint32_t ins=*(uint32_t*)ip, npc=pc+4; n_instr++;
        uint32_t op=ins&0x7f, rd=(ins>>7)&31, f3=(ins>>12)&7, r1=(ins>>15)&31, r2=(ins>>20)&31, f7=ins>>25;
        uint32_t a=x[r1], b=x[r2];
        int32_t sa=(int32_t)a, sb=(int32_t)b;
        uint32_t iI=(uint32_t)((int32_t)ins>>20);
        uint32_t res=0; int wb=1;
        switch(op){
        case 0x37: res=ins&0xfffff000u; break;                       // LUI
        case 0x17: res=pc+(ins&0xfffff000u); break;                  // AUIPC
        case 0x6f: { int32_t im=((ins>>21&0x3ff)<<1)|((ins>>20&1)<<11)|((ins>>12&0xff)<<12)|((int32_t)ins>>31<<20);
                     res=pc+4; npc=pc+im; break; }                   // JAL
        case 0x67: res=pc+4; npc=(a+iI)&~1u; break;                  // JALR
        case 0x63: { int32_t im=((ins>>8&15)<<1)|((ins>>25&63)<<5)|((ins>>7&1)<<11)|((int32_t)ins>>31<<12);
                     int t=0;
                     switch(f3){case 0:t=a==b;break;case 1:t=a!=b;break;case 4:t=sa<sb;break;
                                case 5:t=sa>=sb;break;case 6:t=a<b;break;case 7:t=a>=b;break;}
                     if(t)npc=pc+im; wb=0; break; }
        case 0x03: { uint32_t ad=a+iI;
                     switch(f3){case 0:res=load(ad,1,1);break;case 1:res=load(ad,2,1);break;
                                case 2:res=load(ad,4,0);break;case 4:res=load(ad,1,0);break;
                                case 5:res=load(ad,2,0);break;} break; }
        case 0x23: { int32_t im=((ins>>7)&31)|((int32_t)(ins&0xfe000000))>>20;
                     uint32_t ad=a+im; store(ad,b,f3==0?1:f3==1?2:4); wb=0; break; }
        case 0x13: switch(f3){
                     case 0:res=a+iI;break; case 2:res=sa<(int32_t)iI;break; case 3:res=a<iI;break;
                     case 4:res=a^iI;break; case 6:res=a|iI;break; case 7:res=a&iI;break;
                     case 1:res=a<<(iI&31);break;
                     case 5:res=(f7&0x20)?(uint32_t)(sa>>(iI&31)):(a>>(iI&31));break;} break;
        case 0x33:
            if(f7==1){ switch(f3){
                 case 0:res=(uint32_t)(sa*sb);break;
                 case 1:res=(uint32_t)(((int64_t)sa*(int64_t)sb)>>32);break;
                 case 2:res=(uint32_t)(((int64_t)sa*(uint64_t)b)>>32);break;
                 case 3:res=(uint32_t)(((uint64_t)a*(uint64_t)b)>>32);break;
                 case 4:res=sb==0?0xffffffffu:(sa==INT32_MIN&&sb==-1)?(uint32_t)sa:(uint32_t)(sa/sb);break;
                 case 5:res=b==0?0xffffffffu:a/b;break;
                 case 6:res=sb==0?(uint32_t)sa:(sa==INT32_MIN&&sb==-1)?0:(uint32_t)(sa%sb);break;
                 case 7:res=b==0?a:a%b;break;} }
            else switch(f3){
                 case 0:res=(f7&0x20)?a-b:a+b;break; case 1:res=a<<(b&31);break;
                 case 2:res=sa<sb;break; case 3:res=a<b;break; case 4:res=a^b;break;
                 case 5:res=(f7&0x20)?(uint32_t)(sa>>(b&31)):(a>>(b&31));break;
                 case 6:res=a|b;break; case 7:res=a&b;break;} break;
        case 0x0f: wb=0; break;                                       // FENCE
        case 0x73: wb=0; break;                                       // ECALL/EBREAK/CSR: ignore
        default: fprintf(stderr,"\n[bad op %02x ins=%08x pc=%08x]\n",op,ins,pc); return 1;
        }
        if(wb&&rd) x[rd]=res;
        pc=npc;
    }
}
