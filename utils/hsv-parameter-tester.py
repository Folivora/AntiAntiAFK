#!/usr/bin/env python3

import cv2
import numpy as np
from tkinter import Tk
from tkinter.filedialog import askopenfilename


def nothing(x):
    pass


Tk().withdraw() # we don't want a full GUI, so keep the root window from appearing
imageFile = askopenfilename() # show an "Open" dialog box and return the path to the selected file


# Create a window
windowName='HSV parameter tester'
cv2.namedWindow(windowName)
#cv2.namedWindow('image', cv2.WINDOW_NORMAL)

# create trackbars for color change
cv2.createTrackbar('lowH',windowName,0,179,nothing)
cv2.createTrackbar('highH',windowName,179,179,nothing)

cv2.createTrackbar('lowS',windowName,0,255,nothing)
cv2.createTrackbar('highS',windowName,255,255,nothing)

cv2.createTrackbar('lowV',windowName,0,255,nothing)
cv2.createTrackbar('highV',windowName,255,255,nothing)


while cv2.getWindowProperty(windowName, 0) >= 0:    # Value -1 will returned when the window will be closed by clicking on 'X' button.
                                                    # This might only work for certain GUI backends. Notably, it will not work with 
                                                    # the GTK backend used in Debian/Ubuntu packages. Will work with Qt backend.

    # Reading an image in default mode
    image = cv2.imread(imageFile)

    # get current positions of the trackbars
    ilowH = cv2.getTrackbarPos('lowH', windowName)
    ihighH = cv2.getTrackbarPos('highH', windowName)
    ilowS = cv2.getTrackbarPos('lowS', windowName)
    ihighS = cv2.getTrackbarPos('highS', windowName)
    ilowV = cv2.getTrackbarPos('lowV', windowName)
    ihighV = cv2.getTrackbarPos('highV', windowName)

    # convert color to hsv
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    lower_hsv = np.array([ilowH, ilowS, ilowV])
    higher_hsv = np.array([ihighH, ihighS, ihighV])

    # Apply the cv2.inrange method to create a mask
    mask = cv2.inRange(hsv, lower_hsv, higher_hsv)

    # Apply the mask on the image to extract the original color
    image = cv2.bitwise_and(image, image, mask=mask)
    cv2.imshow(windowName,image)

    key = cv2.waitKey(1)
    if key == 27:                                   # Press <esc> to exit
        break

# closing all open windows
cv2.destroyAllWindows()
