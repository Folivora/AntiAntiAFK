#!/usr/bin/env python3

import numpy as np
import cv2
import argparse
import os


def extractColor(img, lowerValHSV, upperValHSV):
    # Argument's types must be as follows:
    #    img         = cv2.imread(<file>)
    #    lowerValHSV = [85,0,166]
    #    upperValHSV = [255,255,255]

    # convert to HSV
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # set lower and upper color limits
    lower_val = np.array(lowerValHSV)
    upper_val = np.array(upperValHSV)

    # Threshold the HSV image to get only specified colors
    mask = cv2.inRange(hsv, lower_val, upper_val)

    # apply mask to original image - this shows the specified color with black blackground
    only_specified_color = cv2.bitwise_and(img,img, mask= mask)


    # create a black image with the dimensions of the input image
    background = np.zeros(img.shape, img.dtype)
    # invert to create a white image
    background = cv2.bitwise_not(background)

    # invert the mask that blocks everything except specified color -
    # so now it only blocks the specified color area's
    mask_inv = cv2.bitwise_not(mask)

    # apply the inverted mask to the white image,
    # so it now has black where the original image had specified color 
    masked_bg = cv2.bitwise_and(background,background, mask= mask_inv)

    # add the 2 images together. It adds all the pixel values, 
    # so the result is white background and the the specified color from the first image
    finalImg = cv2.add(only_specified_color, masked_bg)

    return finalImg



def convert2BlackWhite(img, threshold, inversed_bw):
    im_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    (thresh, im_bw) = cv2.threshold(im_gray, 128, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)

    im_bw = cv2.threshold(im_gray, threshold, 255, cv2.THRESH_BINARY)[1]

    if inversed_bw:
        im_bw = cv2.bitwise_not(im_bw)

    return im_bw



def main():
    # Construct the argument parser and parse the arguments
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--input-file",  required=True, help="Path to input image file.")
    ap.add_argument("-o", "--output-file", required=False, help="Path to output image file.")
    ap.add_argument("-x", "--extract-color",
                    required=False,
                    dest='hsv_value',
                    help="Extract colors from image.\
                    1st argument: <lower HSV value>, 2nd: <upper HSV value>. Example: -x \"85,0,166\" \"100,255,255\"",
                    nargs=2)
    group = ap.add_mutually_exclusive_group(required=False)
    group.add_argument("-b", "--bw",          dest='threshold_b', type=int, help="Convert image to black&white.")
    group.add_argument("-n", "--inversed-bw", dest='threshold_n', type=int, help="Convert image to negative black&white.")
    args = ap.parse_args()


    # Check if an input image exist & load it. 
    if not os.path.exists(args.input_file):
        print('Input file \"'+args.input_file+'\" does not exist!')
        return 1
    img = cv2.imread(args.input_file)

    # Extract colors
    if args.hsv_value:
        # set HSV values
        lowerValHSV = [int(i)  for i in args.hsv_value[0].split(',')]
        upperValHSV = [int(i)  for i in args.hsv_value[1].split(',')]

        # transform image
        img = extractColor(img, lowerValHSV, upperValHSV)

    # Convert to black&white image
    if args.threshold_b:
        img = convert2BlackWhite(img, args.threshold_b, inversed_bw=False)

    # Convert to inversed black&white image
    if args.threshold_n:
        img = convert2BlackWhite(img, args.threshold_n, inversed_bw=True)


    # Output
    if args.output_file:
        cv2.imwrite(args.output_file, img)
    else:
        cv2.imshow("result image", img)
        cv2.waitKey(0)
        cv2.destroyAllWindows()

    return 0



if __name__ == '__main__':
    main()
