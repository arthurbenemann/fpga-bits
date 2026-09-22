/* picolibc wants unprefixed syscalls + an explicit stderr; the port supplies
   newlib-style _-prefixed ones in libc_backend.c */
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
extern int  _open(const char *, int, int);
extern int  _read(int, char *, int);
extern int  _write(int, const char *, int);
extern int  _close(int);
extern long _lseek(int, long, int);
extern int  _fstat(int, struct stat *);
int  open (const char *p, int f, ...)   { return _open(p, f, 0); }
int  read (int fd, void *b, size_t n)   { return _read(fd, (char*)b, n); }
int  write(int fd, const void *b, size_t n){ return _write(fd, (const char*)b, n); }
int  close(int fd)                      { return _close(fd); }
long lseek(int fd, long o, int w)       { return _lseek(fd, o, w); }
int  fstat(int fd, struct stat *s)      { return _fstat(fd, s); }
static int se_putc(char c, FILE *f) { (void)f; _write(2, &c, 1); return 0; }
static FILE __se = FDEV_SETUP_STREAM(se_putc, NULL, NULL, _FDEV_SETUP_WRITE);
FILE *const stderr = &__se;
extern int _stat(const char *, struct stat *);
int stat(const char *p, struct stat *s) { return _stat(p, s); }
static int so_putc(char c, FILE *f) { (void)f; _write(1, &c, 1); return 0; }
static FILE __so = FDEV_SETUP_STREAM(so_putc, NULL, NULL, _FDEV_SETUP_WRITE);
FILE *const stdout = &__so;
FILE *const stdin  = &__so;
