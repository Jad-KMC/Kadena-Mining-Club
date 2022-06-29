import os

os.chdir('/Users/Todd/Desktop/KMCNFT/ffmpeg')
background = "01Background/background_office.mov" ##
backgear = "02Backgear/backaccessory_bassguitar.mov" ##
backgear2 = "02Backgear/backaccessoryfront_bassguitar.mov" ##
head = "03Head/head_cracked.mov" ##
eye = "04eye/eye_popejoyhexfan.mov" ##
eye2 = "04eye/eyeaccessory_popejoyglass.mov" ##
outfit = "05Outfit/outfit_popejoyshirt.mov" ##
headgear = "06Headgear/headaccessory_martinohair.mov" ##
neck = "08Frontgear/neckaccessory_martinochain.mov" ##
mouth = "07Mouth/mouth_hdmispittingcoins.mov" ##
frontgear = "08Frontgear/frontaccessory_kdboxbaby.mov" ##


# takes a list of 3 or more files and creates ffmpeg command to overlay them in order
# the first element in the list will be the lowest Z element (farthest back)
def generateCommand(files = []):
    command = "ffmpeg"
    i = 0
    count = 0
    alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o"]
    for file in files:
        command += " -i " + file
        count += 1
    command += " -filter_complex \"[0][1]overlay[a];["
    while i < count-3: 
        command += alphabet[i] + "][" + str(i+2) + "]overlay[" + alphabet[i+1] + "];["
        i += 1
    command += alphabet[i] + "][" + str(i+2) + "]overlay\""
    command += " -pix_fmt yuv420p -c:a copy output6.mov"
    return command

# Takes two files and overlays file1 over file2
# This is a separate function because of the different command syntax for less than 3 files
def overlayTwoLayers(file1, file2):
    command = "ffmpeg -i " + file1 + " -i " + file2 + " -filter_complex \"[0:v][1:v] overlay=0:0\" -pix_fmt yuv420p -c:a copy output4.mov"
    os.system(command)

# Call this function with a list of files you want to be compiled
def generateNFT(files):
    command = generateCommand(files)
    os.system(command)

files = []
files.append(background)
files.append(backgear)
files.append(head)
files.append(eye)
files.append(eye2)
files.append(outfit)
files.append(backgear2)
files.append(neck)
files.append(headgear)
files.append(mouth)
files.append(frontgear)

generateNFT(files)


print("done")
