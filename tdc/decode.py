import serial
import matplotlib.pyplot as plt
import numpy as np
from tqdm import tqdm,trange

serial_port = "/dev/ttyUSB1"
baud_rate = 1000000

ser = serial.Serial(serial_port, baud_rate)

data = []
count =0
max_index = 0

for i in trange(10000):
    try:
        # Read data from the serial port up to a newline character
        serial_data = ser.readline().decode().strip()
        num_characters_received = len(serial_data)

        transition_index = None

        if serial_data[0] == '0' and serial_data[1] =='X':
            count +=1
            transition_index = serial_data.find('.') -1    
            max_index = max(transition_index,max_index)


            #print(f"Received: {serial_data} \n received: {num_characters_received},\tindex: {transition_index},\tcount: {count}\tmax: {max_index}")
            data.append(transition_index)

    except KeyboardInterrupt:
        break

# Close the serial port when done
ser.close()


# Create a histogram using Matplotlib
freq = 40               # FPGA freq (MHz)
period = 1e6/freq    # period (ps)

fig, ax1 = plt.subplots()
ax1.hist(data, bins=max(data)-min(data)+1, density=True, 
#        histtype="step", cumulative=True,
        color='blue', edgecolor='black')  # Adjust the number of bins as needed
y_vals = ax1.get_yticks()
ax1.set_yticklabels(['{:3.0f}'.format(x *period) for x in y_vals])

# Customize the plot
plt.title('TDC cell propagation speed')
plt.xlabel('Index')
plt.ylabel('ps')
ax1.grid(True)

# Step 4: Display the plot
plt.show()
