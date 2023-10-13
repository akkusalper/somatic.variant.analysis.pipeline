#!/bin/bash

FASTQC_DOCKER_IMAGE="docker.io/biocontainers/fastqc:v0.11.9_cv8"
BERGUN_BWA_SAMTOOLS="bergun/bwa-mem2_samtools:0.0.1"
GATK="broadinstitute/gatk:latest"
REFERENCE="Homo_sapiens_assembly38.fasta"
TUMOR_FASTQ_LEFT=$1
TUMOR_FASTQ_RIGHT=$2
TUMOR_SAMPLE_NAME=$3
BED_INTERVAL_LIST=${4:-""}
DBSNP="Homo_sapiens_assembly38.dbsnp138.vcf"
PON="1000g_pon.hg38.vcf.gz"
AF_ONLY_GNOMAD="af-only-gnomad.hg38.vcf.gz"
LOD="alperakkus/vlod:12.10.2023"

# Quality check
docker run -v $(pwd):/data --rm $FASTQC_DOCKER_IMAGE fastqc /data/$TUMOR_FASTQ_LEFT /data/$TUMOR_FASTQ_RIGHT

# Alignment
docker run -v $(pwd):/data --rm $BERGUN_BWA_SAMTOOLS bwa-mem2 mem -R "@RG\tID:id\tSM:$TUMOR_SAMPLE_NAME\tLB:lib" /data/$REFERENCE /data/$TUMOR_FASTQ_LEFT /data/$TUMOR_FASTQ_RIGHT > $TUMOR_SAMPLE_NAME.sam

docker run -v $(pwd):/data --rm $BERGUN_BWA_SAMTOOLS samtools view -b /data/$TUMOR_SAMPLE_NAME.sam > $TUMOR_SAMPLE_NAME.bam

docker run -v $(pwd):/data --rm $BERGUN_BWA_SAMTOOLS sh -c "samtools sort /data/$TUMOR_SAMPLE_NAME.bam -o /data/$TUMOR_SAMPLE_NAME.2.sorted.bam" > $TUMOR_SAMPLE_NAME.sort.log 2>&1

docker run -v $PWD:/data $GATK gatk AddOrReplaceReadGroups \
    -I /data/$TUMOR_SAMPLE_NAME.2.sorted.bam \
    -O /data/$TUMOR_SAMPLE_NAME.sorted.bam \
    --RGID id \
    --RGLB lib \
    --RGPL illumina \
    --RGPU unit1 \
    --RGSM $TUMOR_SAMPLE_NAME

# Mark duplicates with GATK using Docker
docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" MarkDuplicatesSpark -I $TUMOR_SAMPLE_NAME.sorted.bam -O $TUMOR_SAMPLE_NAME.tumor.marked.bam -M $TUMOR_SAMPLE_NAME.tumor.metrics.txt --remove-sequencing-duplicates

# Base quality score recalibration (BQSR)
if [[ -n "$BED_INTERVAL_LIST" ]]; then
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" BaseRecalibrator -R $REFERENCE -I $TUMOR_SAMPLE_NAME.tumor.marked.bam --known-sites $DBSNP -L $BED_INTERVAL_LIST -O $TUMOR_SAMPLE_NAME.tumor.recal_data.table
else
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" BaseRecalibrator -R $REFERENCE -I $TUMOR_SAMPLE_NAME.tumor.marked.bam --known-sites $DBSNP -O $TUMOR_SAMPLE_NAME.tumor.recal_data.table
fi

docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" ApplyBQSRSpark -R $REFERENCE -I $TUMOR_SAMPLE_NAME.tumor.marked.bam --bqsr $TUMOR_SAMPLE_NAME.tumor.recal_data.table -O $TUMOR_SAMPLE_NAME.tumor.recal.bam

# Mutect2
if [[ -n "$BED_INTERVAL_LIST" ]]; then
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" Mutect2 -R $REFERENCE -I $TUMOR_SAMPLE_NAME.tumor.recal.bam --germline-resource $AF_ONLY_GNOMAD --panel-of-normals $PON -L $BED_INTERVAL_LIST -O $TUMOR_SAMPLE_NAME.somatic.unfiltered.vcf.gz
else
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" Mutect2 -R $REFERENCE -I $TUMOR_SAMPLE_NAME.tumor.recal.bam --germline-resource $AF_ONLY_GNOMAD --panel-of-normals $PON -O $TUMOR_SAMPLE_NAME.somatic.unfiltered.vcf.gz
fi

# FilterMutectCalls
if [[ -n "$BED_INTERVAL_LIST" ]]; then
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" FilterMutectCalls -R $REFERENCE -V $TUMOR_SAMPLE_NAME.somatic.unfiltered.vcf.gz -L $BED_INTERVAL_LIST -O $TUMOR_SAMPLE_NAME.somatic.filtered.vcf.gz
else
    docker run -v $PWD:/data --rm -w /data -t $GATK gatk --java-options "-Xmx80G" FilterMutectCalls -R $REFERENCE -V $TUMOR_SAMPLE_NAME.somatic.unfiltered.vcf.gz -O $TUMOR_SAMPLE_NAME.somatic.filtered.vcf.gz
fi

# Unzip the filtered VCF and run the LOD script
gunzip $TUMOR_SAMPLE_NAME.somatic.filtered.vcf.gz
docker run -v $PWD:/data --rm -w /data -t --entrypoint python alperakkus/vlod:12.10.2023 /usr/src/app/LOD_11_05_23_updated_14_08_23.py --input-vcf $TUMOR_SAMPLE_NAME.somatic.filtered.vcf --input-bam $TUMOR_SAMPLE_NAME.tumor.recal.bam --input-bam-index $TUMOR_SAMPLE_NAME.tumor.recal.bam.bai --output $TUMOR_SAMPLE_NAME.detectability.status.xls

# Integrate detectability status into the VCF
docker run -v $PWD:/data --rm -w /data -t --entrypoint python alperakkus/vlod:12.10.2023 /usr/src/app/merge_detectability.py /data/$TUMOR_SAMPLE_NAME.somatic.filtered.vcf /data/$TUMOR_SAMPLE_NAME.detectability.status.xls /data/$TUMOR_SAMPLE_NAME.somatic.with_detectability.vcf
