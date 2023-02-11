#!/usr/bin/env python3

from pytesseract import Output
import pytesseract
import cv2
import argparse


def get_coordinates(input_img, min_conf, phrase, output_img):

    TriggerPhrase = str(phrase).split(sep=None, maxsplit=-1)
    
    # load the input image, convert it from BGR to RGB channel ordering,
    # and use Tesseract to localize each area of text in the input image
    image = cv2.imread(input_img)
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = pytesseract.image_to_data(image, output_type=Output.DICT)
    
    blocks = {}
    # regroup all the individual text localizations by block_num in blocks variable
    for i in range(0, len(results["text"])):
        if int(results["conf"][i]) > min_conf:           # confidence filter
    
            # if statement for debug purpose
            if output_img is not None:
                # extract the bounding box coordinates of the text region from the current result
                x = results["left"][i]
                y = results["top"][i]
                w = results["width"][i]
                h = results["height"][i]
                # extract the OCR text itself along with the confidence of the text localization
                text = results["text"][i]
                conf = int(results["conf"][i])
                # strip out non-ASCII text so we can draw the text on the image using OpenCV, 
                # then draw a bounding box around the text along with the text itself
                text = "".join([c if ord(c) < 128 else "" for c in text]).strip()
                cv2.rectangle(image, (x, y), (x + w, y + h), (0, 255, 0), 1)
                cv2.putText(image, text, (x, y - 30), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)
    
    
            if not results["block_num"][i] in blocks:
                blocks[results["block_num"][i]]=[] 
            blocks[results["block_num"][i]].append((results["text"][i],results["left"][i],results["top"][i],results["width"][i],results["height"][i]))
    
    if output_img is not None:
        cv2.imwrite(output_img, image)
    
    
    # search the TriggerPhrase
    x, y = 0, 0
    for keyval in list(blocks.items()):     # for each block_num (block - set of words)
        for wordNumInBlock in range(0, len(keyval[1])):  # for each word in current block 
                                                         # (len(keyval[1]) - count of words in current block_num)
    
            if keyval[1][wordNumInBlock][0] == TriggerPhrase[0]:
                # if (count of words in current block) - (number of curr word in curr block) >= (count of words in TriggerPhrase)
                if len(keyval[1])-wordNumInBlock >= len(TriggerPhrase): 
    
                    # compare every next word in the TriggerPhrase with every next word in current block 
                    diffFound=False
                    for i in range(0, len(TriggerPhrase)):
                        if keyval[1][wordNumInBlock+i][0] != TriggerPhrase[i]:
                            diffFound=True
                            break
                    if not diffFound:
                        x=keyval[1][wordNumInBlock][1]
                        y=keyval[1][wordNumInBlock][2]
                        #print("trigger phrase found")
                        #print(keyval[1][wordNumInBlock][1]) # x (from the left side)
                        #print(keyval[1][wordNumInBlock][2]) # y (from the top side)
                        #print(keyval[1][wordNumInBlock][3]) # width of block
                        #print(keyval[1][wordNumInBlock][4]) # height of block
    
    if x!=0 and y!=0:
        print("({} {})".format(x, y))


def main():
    # construct the argument parser and parse the arguments
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--image", required=True,
    	help="path to input image to be OCR'd")
    ap.add_argument("-c", "--min-conf", type=int, default=0,
    	help="mininum confidence value to filter weak text detection")
    ap.add_argument("-p", "--phrase", type=str, required=True,
    	help="Thrigger phrase for search")
    ap.add_argument("-d", "--detail-img", type=str,
    	help="path to output image")
    args = vars(ap.parse_args())

    get_coordinates(input_img=args["image"], min_conf=args["min_conf"], phrase=args["phrase"], output_img=args["detail_img"])


if __name__ == '__main__':
    main()
