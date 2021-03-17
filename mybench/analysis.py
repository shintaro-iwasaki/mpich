
import sys

if len(sys.argv) != 2:
    print("Usage: python analysis.py PATH")
    exit(-1)

path = sys.argv[1]

data_dic = {}
label_list = []
nentities_list = []
winsize_list = []

for line in open(path):
    if line.startswith("#### "):
        label = line.split(" ")[1].strip()
        if not label in label_list:
            label_list.append(label)
        nentities = line.split(" ")[3].strip()
        if not nentities in nentities_list:
            nentities_list.append(nentities)
    if line.startswith("Window size: "):
        winsize = line.split("Window size: ")[1].strip()
        if not winsize in winsize_list:
            winsize_list.append(winsize)
    if line.startswith("Total message rates: "):
        msgrate = float(line.split("Total message rates: ")[1].split(" ")[0].strip())
        key = label + "_" + nentities + "_" + winsize
        if not key in data_dic:
            data_dic[key] = []
        data_dic[key].append(msgrate)

for winsize in winsize_list:
    print("## winsize: " + str(winsize))
    desc = ""
    for label in label_list:
        desc += "\t" + label
    desc += "\n"
    for nentities in nentities_list:
        desc += nentities
        for label in label_list:
            key = label + "_" + nentities + "_" + winsize
            val = 0
            if len(data_dic[key]) > 0:
                val = sum(data_dic[key]) / len(data_dic[key])
            desc += "\t" + str(val)
        desc += "\n"
    desc += "\n"
    print(desc)

for nentities in nentities_list:
    print("## nentities: " + str(nentities))
    desc = ""
    for label in label_list:
        desc += "\t" + label
    desc += "\n"
    for winsize in winsize_list:
        desc += winsize
        for label in label_list:
            key = label + "_" + nentities + "_" + winsize
            val = 0
            if len(data_dic[key]) > 0:
                val = sum(data_dic[key]) / len(data_dic[key])
            desc += "\t" + str(val)
        desc += "\n"
    desc += "\n"
    print(desc)


