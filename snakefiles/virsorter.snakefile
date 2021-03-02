

test_genomes = os.path.join(workflow.basedir, "../genbank")
EdwardsLab = os.path.join(workflow.basedir, "../EdwardsLab")
scripts = os.path.join(workflow.basedir, "../scripts")
GENOMES, = glob_wildcards(os.path.join(test_genomes, '{genome}.gb.gz'))

outputdir = "virsorter_tests"


rule all:
    input:
        expand(os.path.join(outputdir, "{genome}_virsorter_tptn.tsv"), genome=GENOMES)


rule convert_gb_to_fna:
    input:
        gen = os.path.join(test_genomes, "{genome}.gb.gz")
    output:
        fna = os.path.join(outputdir, "{genome}.fna")
    conda:
        "../conda_environments/roblib.yaml"
    shell:
        """
        export PYTHONPATH=$PYTHONPATH:{EdwardsLab}
        python3 {EdwardsLab}/bin/genbank2sequences.py -g {input.gen} -n {output.fna}
        """


rule run_virsorter:
    input:
        fna = os.path.join(outputdir, "{genome}.fna")
    output:
        c1 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-1.gb"),
        c2 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-2.gb"),
        c3 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-3.gb"),
        c4 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_prophages_cat-4.gb"),
        c5 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_prophages_cat-5.gb"),
    params:
        odir = os.path.join(outputdir, "{genome}_virsorter")
    benchmark:
        os.path.join(outputdir, "benchmarks", "{genome}_virsorter.txt")
    conda:
        "../conda_environments/virsorter.yaml"
    shell:
        """
        wrapper_phage_contigs_sorter_iPlant.pl --ncpu 1 -f {input.fna} --db 1 --wdir {params.odir} --data-dir ~/opt/virsorter/virsorter-data
        """

rule virsorter_to_tbl:
    input:
        c1 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-1.gb"),
        c2 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-2.gb"),
        c3 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_cat-3.gb"),
        c4 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_prophages_cat-4.gb"),
        c5 = os.path.join(outputdir, "{genome}_virsorter", "Predicted_viral_sequences/VIRSorter_prophages_cat-5.gb"),
    output:
        os.path.join(outputdir, "{genome}_virsorter", "locs.tsv")
    shell:
        """
        set +e
        G=$(grep -h LOCUS {input.c1} {input.c2} {input.c3});
        exitcode=$?
        if [ $exitcode == 0 ]; then
            echo $G | awk '{{print $2"\t1\t"$3}}' | sed -e 's/VIRSorter_//' > {output};
        elif [ $exitcode == 1 ]; then
            touch {output}
        else
            exit $exitcode
        fi

        G=$(grep -h LOCUS {input.c4} {input.c5})
        exitcode=$?
        if [ $exitcode == 0 ]; then
            echo $G | awk '{{print $2}}' | perl -pe 's/VIRSorter_(\S+)_gene_\d+_gene_\d+-(\d+)-(\d+)-.*/$1\t$2\t$3/' >> {output}
        elif [ $exitcode == 1 ]; then
            touch {output}
        else
            exit $exitcode
        fi
        """

rule count_tp_tn:
    input:
        gen = os.path.join(test_genomes, "{genome}.gb.gz"),
        tbl = os.path.join(outputdir, "{genome}_virsorter", "locs.tsv")
    output:
        tp = os.path.join(outputdir, "{genome}_virsorter_tptn.tsv")
    shell:
        """
        python3 {scripts}/compare_predictions_to_phages.py -t {input.gen} -r {input.tbl} > {output.tp}
        """
