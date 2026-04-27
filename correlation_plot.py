import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation

ser = serial.Serial('/dev/cu.usbmodem101', 115200)
data = []

fig, ax = plt.subplots()
line, = ax.plot([], [])
ax.set_ylim(-1.25, 1.25)
ax.set_xlabel('Sample')
ax.set_ylabel('Normalised Correlation')
ax.axhline(0, color='gray', linestyle='--')

def update(frame):
    try:
        val = float(ser.readline().decode().strip())
        data.append(val)
        if len(data) > 500:  # keep last 500 points
            data.pop(0)
        line.set_data(range(len(data)), data)
        ax.set_xlim(0, len(data))
    except:
        pass
    return line,

ani = animation.FuncAnimation(fig, update, interval=50)
plt.show()