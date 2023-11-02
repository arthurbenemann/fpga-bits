import serial
import matplotlib.pyplot as plt
import numpy as np

serial_port = "/dev/ttyUSB1"
baud_rate = 1000000

ser = serial.Serial(serial_port, baud_rate)

data = []
count =0
max_index = 0

while True:
    try:
        # Read data from the serial port up to a newline character
        serial_data = ser.readline().decode().strip()
        num_characters_received = len(serial_data)

        transition_index = None
        previous_char = ""

        for index, char in enumerate(serial_data):
            if char == '0' and previous_char == '.':
                transition_index = index
                count +=1
                max_index = max(transition_index,max_index)
                break

            previous_char = char

        if transition_index is not None:
            print(f"\nReceived: {serial_data} \n received: {num_characters_received},\tindex: {transition_index},\tcount: {count}\tmax: {max_index}")
            data.append(transition_index)

    except KeyboardInterrupt:
        break

# Close the serial port when done
ser.close()


# Create a histogram using Matplotlib
plt.hist(data, bins=max(data)-min(data)+1, color='blue', edgecolor='black')  # Adjust the number of bins as needed

# Customize the plot
plt.title('Histogram of Random Data')
plt.xlabel('Value')
plt.ylabel('Frequency')

# Step 4: Display the plot
plt.show()
