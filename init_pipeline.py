from argparse import ArgumentParser
from glob import glob
from posixpath import basename
import shutil
import os
import json
import subprocess

'''
takes an --input directory of fasta files,
    prompts user for PWI for each subject,
    runs through pipeline,
    and an places generated output at --output

example:
    python3 init_pipeline.py -in /home/node/app/input -out /home/node/app/jobs/subject_1

-in can contain any subfolder structure but files must be named {subject}_{sample}.fasta
    to be arranged into corresponding subfolders (samples.json) and Start2Art (conversion.json)

-out will be created if it does not exist, and will contain the output of the pipeline
'''

parser = ArgumentParser()
parser.add_argument("-input", "--input", help="")
parser.add_argument("-output", "--output", help="")
args = parser.parse_args()

if not args.input or not args.output:
    print("Please provide an input and output location")
    exit(1)

if not os.path.exists(args.input):
    print("Input directory does not exist")
    exit(1)

if os.path.exists(args.output):
    shutil.rmtree(args.output)

input_dir = args.input
output_dir = args.output

if not input_dir.endswith('/'):
    input_dir += "/"
if not output_dir.endswith('/'):
    output_dir += "/"

fasta_files = glob(f"{input_dir}**/*.fasta", recursive=True)

samples = []
conversion = {}

for file in fasta_files:
    split_filename = basename(file).split('_', 1)
    subject = split_filename[0]
    sample = split_filename[1]

    new_dir = f"{output_dir}data/{subject}"
    update_file_location = f"{new_dir}/{subject}_{sample}"

    os.makedirs(new_dir, exist_ok=True)
    shutil.copy(file, update_file_location)

    samples.append(f"{subject}/{subject}_{sample}")

    if not subject in conversion:
        pwi = input(f"Enter the Post Weeks Infection for {subject}: ")
        conversion[subject] = {
            "Start2ART": pwi
        }

with open(f"{output_dir}conversion.json", 'w') as fp:
    json.dump(conversion, fp)

with open(f"{output_dir}samples.json", 'w') as fp:
    json.dump({"samples": samples, "job_dir": output_dir}, fp)

print(f"Running pipeline...job_dir='{output_dir}'")

pipeline_result = subprocess.run(
    f"snakemake --keep-incomplete --keep-going --cores 4 --configfile {output_dir}samples.json",
    shell=True,
    # capture_output = True
)

if(pipeline_result.returncode != 0):
    print("Pipeline failed")
    # print(pipeline_result.stdout)
    # print(pipeline_result.stderr)
    exit(1)

# print("Running result summary...")
# subprocess.run(f"$python3 /home/node/app/scripts/result-summary.py -d {output_dir}results/dating/ -j {output_dir}conversion.json -o {output_dir}results/summary.csv")