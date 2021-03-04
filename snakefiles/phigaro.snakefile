

outputdir = "phigaro_tests"


include: "../scripts/preflight.smk"


rule all:
    input:
        expand(os.path.join(outputdir, "{genome}_phigaro_tptn.tsv"), genome=GENOMES)


rule run_phigaro:
    input:
        fna = os.path.join(outputdir, "{genome}.fna")
    output:
        tsv = "{genome}_phigaro.tsv"
    params:
        tsv = "{genome}_phigaro" # phigaro adds the .tsv extension
    benchmark:
        os.path.join(outputdir, "benchmarks", "{genome}_phigaro.txt")
    conda:
        "../conda_environments/phigaro.yaml"
    shell:
        """
        phigaro -f {input.fna} -e tsv -o {params.tsv} --delete-shorts
        """

rule phigaro_to_tbl:
    input:
        tsv = "{genome}_phigaro.tsv"
    output:
        os.path.join(outputdir, "{genome}_phigaro_locs.tsv")
    shell:
        """
        if [ $(stat -c %s {input}) -lt 50 ]; then
            touch {output}
        else
            grep -v scaffold {input.tsv} | cut -f 1,2,3 > {output}
        fi
        """

rule count_tp_tn:
    input:
        gen = os.path.join(test_genomes, "{genome}.gb.gz"),
        tbl = os.path.join(outputdir, "{genome}_phigaro_locs.tsv")
    output:
        tp = os.path.join(outputdir, "{genome}_phigaro_tptn.tsv")
    params:
        os.path.join(workflow.basedir,'../')
    shell:
        """
        export PYTHONPATH={params};
        python3 scripts/compare_predictions_to_phages.py -t {input.gen} -r {input.tbl} > {output.tp}
        """
