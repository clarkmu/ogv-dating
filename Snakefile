import os, sys

INPUT_DIR           = "data"
ALIGNMENT_DIR       = "results/alignments"
TREE_DIR            = "results/trees"
CALLS_DIR           = "results/dating"

TREES      = ['classification.csv']

callables = {
    'hyphy' : '/usr/local/bin/hyphy',
    'mafft' : '/usr/local/bin/mafft --auto ',
    'raxml' : '/usr/local/bin/raxml-ng',
    'fasttree' : '/usr/local/bin/FastTree',
    'classifier' : 'scripts/compute-distance.js'
}

if config and config['job_dir'] and len(config['job_dir']) > 0:
    job_dir = config['job_dir']

    INPUT_DIR           = f"{job_dir}data"
    ALIGNMENT_DIR       = f"{job_dir}results/alignments"
    TREE_DIR            = f"{job_dir}results/trees"
    CALLS_DIR           = f"{job_dir}results/dating"

    callables = {
        'hyphy' : 'hyphy',
        'mafft' : 'mafft --auto ',
        'raxml' : 'raxml-ng',
        'fasttree' : 'FastTree',
        'classifier' : 'scripts/compute-distance.js'
    }
else:
    configfile: "samples.json"

print(config)

wildcard_constraints:
    subject="\w+"

for d in [INPUT_DIR, ALIGNMENT_DIR, TREE_DIR, CALLS_DIR]:
    if not os.path.isdir (d):
        os.makedirs (d)

def ensure_all_directories_exist ():
    IDS,SAMPLES = glob_wildcards(INPUT_DIR + "/{id}/{sample}.fasta")
    for id in set (IDS):
        for d in [ALIGNMENT_DIR, TREE_DIR, CALLS_DIR]:
            os.makedirs ("%s/%s" % (d,id), exist_ok=True)
    inputs = expand("%s/{sample}_{extension}" % CALLS_DIR, sample=config["samples"], extension = TREES)
    return inputs

rule all:
    input:
        ensure_all_directories_exist ()


rule read_qc:
    threads: 1
    input:
        #ensure_alignment
        "%s/{subject}/{sample}" % INPUT_DIR
    output:
        combined_protein = "%s/{subject}/{sample}_combined_protein.fas" % ALIGNMENT_DIR,
        combined_nuc = "%s/{subject}/{sample}_combined_nuc.fas" % ALIGNMENT_DIR,
        protein = "%s/{subject}/{sample}_protein.fas" % ALIGNMENT_DIR,
        nuc_data = "%s/{subject}/{sample}_nuc.fas" % ALIGNMENT_DIR,
        qvoa = "%s/{subject}/{sample}_qvoa.fas" % ALIGNMENT_DIR
    shell:
        "%s HBL/data_filter.bf --input {input} --qvoa {output.qvoa} --protein {output.protein} --rna {output.nuc_data} --combined-rna {output.combined_nuc} --combined-protein {output.combined_protein}" % callables['hyphy']

rule make_protein_msa_rna:
    threads: 1
    input:
        "%s/{subject}/{tag}_protein.fas" % ALIGNMENT_DIR
    output:
        "%s/{subject}/{tag}_rna_protein.msa" % ALIGNMENT_DIR
    shell:
        "%s {input} > {output} 2>/dev/null" % callables['mafft']

rule make_protein_msa_combined:
    input:
        "%s/{subject}/{sample}_combined_protein.fas" % ALIGNMENT_DIR
    output:
        "%s/{subject}/{sample}_combined_protein.msa" % ALIGNMENT_DIR
    shell:
        "%s {input} > {output} 2>/dev/null" % callables['mafft']

rule make_codon_msa_rna:
    threads: 1
    input:
        "%s/{subject}/{sample}_rna_protein.msa" % ALIGNMENT_DIR,
        "%s/{subject}/{sample}_nuc.fas" % ALIGNMENT_DIR
    output:
        "%s/{subject}/{sample}_rna.msa" % ALIGNMENT_DIR
    shell:
        "%s HBL/data_filter-2.bf {input} {output}" % callables['hyphy']

rule make_codon_msa_combined:
    threads: 1
    input:
        "%s/{subject}/{sample}_combined_protein.msa" % ALIGNMENT_DIR,
        "%s/{subject}/{sample}_combined_nuc.fas" % ALIGNMENT_DIR
    output:
        "%s/{subject}/{sample}_combined.msa" % ALIGNMENT_DIR
    shell:
        "%s HBL/data_filter-2.bf {input} {output}" % callables['hyphy']

rule infer_ml_rna_tree:
    threads: 1
    input:
        "%s/{subject}/{sample}_rna.msa" % ALIGNMENT_DIR,
    output:
        "%s/{subject}/{sample}_rna_unscaled.nwk" % TREE_DIR
    shadow:
        "shallow"
    shell:
        #"%s --msa {input} --force --model GTR --tree pars ; mv {input}.raxml.bestTree {output} " % callables['raxml']
        "%s -nt -gtr -gamma -slow < {input} > {output}" % callables ["fasttree"]

rule infer_ml_rna_tree_lengths:
    input:
        msa = "%s/{subject}/{sample}_rna.msa" % ALIGNMENT_DIR,
        tree = "%s/{subject}/{sample}_rna_unscaled.nwk" % TREE_DIR
    output:
        "%s/{subject}/{sample}_rna.nwk" % TREE_DIR
    shadow:
        "shallow"
    shell:
        "%s HBL/branch-lengths.bf {input.msa} {input.tree} {output}" % callables['hyphy']


rule infer_ml_tree:
    threads: 1
    input:
        "%s/{subject}/{sample}_combined.msa" % ALIGNMENT_DIR,
    output:
        "%s/{subject}/{sample}_combined_unscaled.nwk" % TREE_DIR
    shadow:
        "shallow"
    shell:
        "%s -nt -gtr < {input} > {output}" % callables ["fasttree"]
        #"%s --msa {input} --force --model GTR --tree pars ; mv {input}.raxml.bestTree {output} " % callables['raxml']

rule infer_ml_tree_lengths:
    input:
        msa = "%s/{subject}/{sample}_combined.msa" % ALIGNMENT_DIR,
        tree = "%s/{subject}/{sample}_combined_unscaled.nwk" % TREE_DIR
    output:
        "%s/{subject}/{sample}_combined.nwk" % TREE_DIR
    shadow:
        "shallow"
    shell:
        "%s HBL/branch-lengths.bf {input.msa} {input.tree} {output}" % callables['hyphy']


rule perform_placement:
    threads: 4
    input:
        "%s/{subject}/{sample}_rna.msa" % ALIGNMENT_DIR,
        "%s/{subject}/{sample}_rna.nwk" % TREE_DIR
    output:
        "%s/{subject}/{sample}_placement.tsv" % CALLS_DIR,
        "%s/{subject}/{sample}_full_placement.tsv" % CALLS_DIR
    shell:
        "cat {input} > %s/{wildcards.subject}/{wildcards.sample}.scueal; %s HBL/scripts/screen_fasta.bf %s/{wildcards.subject}/{wildcards.sample}.scueal %s/{wildcards.subject}/{wildcards.sample}_qvoa.fas {output}" % (CALLS_DIR, callables['hyphy'], CALLS_DIR, ALIGNMENT_DIR  )

rule perform_classification:
    threads: 1
    input:
        newick = "%s/{subject}/{sample}_combined.nwk" % TREE_DIR,
        placement = "%s/{subject}/{sample}_full_placement.tsv" % CALLS_DIR
    output:
        "%s/{subject}/{sample}_classification.csv" % CALLS_DIR
    shell:
        "%s -n {input.newick} -r 'OGV,QVOA|OGV|DNA' RNA,NGS -f RNA -p  {input.placement} > {output} " % callables['classifier']
