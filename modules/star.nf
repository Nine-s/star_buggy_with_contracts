process STAR_INDEX_REFERENCE {
    label 'star'
    publishDir params.outdir
    
    input:
    path(reference)
    path(annotation)

    output:
    path("star/*")

    require(["""exit 0
import sys
import os

for file in [f for f in os.listdir() if f.endswith(".fa")]:
        with open(file) as f:
                for line in f:
                        if line[0] not in [">", "A", "C", "T", "G", "U", "N", ";"]:
                                sys.exit(1)"""])
    promise([COMMAND_LOGGED_NO_ERROR(), INPUTS_NOT_CHANGED()])

    script:
    """
    mkdir star
    STAR \\
            --runMode genomeGenerate \\
            --genomeDir star/ \\
            --genomeFastaFiles ${reference} \\
            --sjdbGTFfile ${annotation} \\
            --runThreadN ${params.threads} \\
	
    """
}

process STAR_ALIGN {
    label 'star'
    publishDir params.outdir
    
    input:
    tuple val(sample_name), path(reads)
    path(index)
    path(annotation)

    output:
    tuple val(sample_name), path("${sample_name}*.sam"), emit: sample_sam 

    promise([
        FOR_ALL("f", ITER("*.sam"), { f -> IF_THEN(EMPTY_FILE(f), "exit 1")}), COMMAND_LOGGED_NO_ERROR(), INPUTS_NOT_CHANGED()
    ])

    script:
    """
    STAR \\
        --genomeDir . \\
        --readFilesIn ${reads[0]} ${reads[1]}  \\
        --runThreadN ${params.threads} \\
        --outFileNamePrefix ${sample_name}. \\
        --sjdbGTFfile ${annotation}

    """
}
