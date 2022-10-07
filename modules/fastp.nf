process FASTP {
    label 'fastp'
    publishDir params.outdir

    input:
    tuple val(name), path(reads)

    output:
    tuple val(name), path("${name}*.trimmed.fastq"), emit: sample_trimmed
    path "${name}_fastp.json", emit: report_fastp_json
    path "${name}_fastp.html", emit: report_fastp_html
    
    require([
	FOR_ALL("f", ITER("*.fastq"), 
		{ f -> 
			IF_THEN(
				NOT(
					EQUAL(
						NUM("\$(( \$(wc -l $f | cut -d' ' -f1)/4*4 ))"), 
						NUM("\$(wc -l $f | cut -d' ' -f1)")
					)
				), 
				"exit 1"
			)
		}
	), 
	"""for file in *.fastq; do 
		if ! awk 'BEGIN{c=0;} {if (c % 4 == 0 && substr(\$0,1,1) != "@" || substr(\$0,1,1) == "@ ") {exit 1} if (c % 4 == 1) {len = length(\$0)} if (c % 4 == 2 && substr(\$0,1,1) != "+") {exit 1} if (c % 4 == 3 && len != length(\$0)) {exit 1} c = c+1}' \$file; then 
			exit 1; 
		fi;
	done"""
])
    promise([FOR_ALL("f", ITER("*_fastp.json"), {f -> IF_THEN(EMPTY_FILE(f), "exit 1")}), FOR_ALL("f", ITER("*.trimmed.fastq"), {f -> IF_THEN(EMPTY_FILE(f), "exit 1")}), "reads=\$(grep total_reads *.json | head -n2 | grep -Po '\\d*'); if [ \$(( \$(( \$(echo \$reads | cut -d' ' -f 1) - \$(echo \$reads | cut -d' ' -f 2))) * 100 / \$(echo \$reads | cut -d' ' -f 1) )) -gt 95 ]; then exit 1; fi", FOR_ALL("f", ITER("*.trimmed.fastq"), { f -> IF_THEN(NOT(EQUAL(NUM("\$((\$(wc -l $f | cut -d' ' -f1)/4*4))"), NUM("\$(wc -l $f | cut -d' ' -f1)"))), "exit 1")}), 
	"""for file in *.trimmed.fastq; do if ! awk 'BEGIN{c=0;} {if (c % 4 == 0 && substr(\$0,1,1) != "@" || substr(\$0,1,1) == "@ ") {exit 1} if (c % 4 == 1) {len = length(\$0)} if (c % 4 == 2 && substr(\$0,1,1) != "+") {exit 1} if (c % 4 == 3 && len != length(\$0)) {exit 1} c = c+1}' \$file; then exit 1; fi; done""", COMMAND_LOGGED_NO_ERROR(), INPUTS_NOT_CHANGED()])

    script:
    """
    fastp -i ${reads[0]} -I ${reads[1]} -o ${name}.R1.trimmed.fastq -O ${name}.R2.trimmed.fastq --detect_adapter_for_pe --json ${name}_fastp.json --html ${name}_fastp.html --thread ${params.threads}
    """
}
