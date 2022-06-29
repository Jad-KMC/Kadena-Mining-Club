

background = "01Background/Untitled_Artwork7.png"
backgear = "02Backgear/Surfboard-01.png"
head = "03Head/Goldhead_Goldshell1.png"
eye = "04eye/Keye-01.png"
outfit = "05Outfit/Summershirt-01.png"
headgear = "06Headgear/PopejoyHair_Goldshell1.png"
mouth = "hdmiSpitting.mov"
frontgear = "08Frontgear/TreePot-01.png"

files = []

files.append(background)
files.append(backgear)
files.append(head)
files.append(eye)
files.append(outfit)
files.append(headgear)
files.append(mouth)
files.append(frontgear)

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
    while i < count-3: #count=4
        command += alphabet[i] + "][" + str(i+2) + "]overlay[" + alphabet[i+1] + "];["
        i += 1
    command += alphabet[i] + "][" + str(i+2) + "]overlay\""
    command += " -pix_fmt yuv420p -c:a copy output3.mov"
    print(command)

generateCommand(files)
