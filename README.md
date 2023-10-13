# somatic single nucleotide variant (SNV) analysis pipeline
an example open source somatic variant analysis pipeline (insight from GATK Best Practices). vLoD algorithm is also integrated.

## Introduction

vLoD (Variant Level of Detectability) Predictor is a sophisticated pipeline designed to analyze tumor samples, call variants, and predict their detectability. The pipeline encompasses multiple phases, from quality control to alignment, variant calling, and finally, the integration of detectability status into the VCF.

## Requirements

- Docker: The pipeline uses Docker containers to encapsulate the required tools and their dependencies.
- Reference Files:
  - A human reference genome (e.g., `Homo_sapiens_assembly38.fasta`)
  - A dbSNP VCF file (e.g., `Homo_sapiens_assembly38.dbsnp138.vcf`)
  - A panel of normals (PON) VCF file (e.g., `1000g_pon.hg38.vcf.gz`)
  - An allele frequency-only gnomAD VCF file (e.g., `af-only-gnomad.hg38.vcf.gz`)

## Docker Images Used

- FastQC for quality control checks: `docker.io/biocontainers/fastqc:v0.11.9_cv8`
- BWA and SAMtools for alignment: `bergun/bwa-mem2_samtools:0.0.1`
- GATK for various genomics processes: `broadinstitute/gatk:latest`
- vLoD for detectability prediction: `alperakkus/vlod:12.10.2023`

## Usage

The primary script requires four inputs: the paths to the left and right FASTQ files of the tumor sample, the tumor sample name, and optionally a BED interval list. 

### Materials and Methods
#### Quality Control: Utilizes FastQC to perform quality checks on raw reads.
#### Alignment: Aligns reads to a reference genome using BWA-MEM2, followed by SAM to BAM conversion and sorting with SAMtools.
#### Marking Duplicates: Identifies and marks duplicate reads using GATK's MarkDuplicatesSpark.
#### BQSR (Base Quality Score Recalibration): Corrects base quality scores with GATK's BaseRecalibrator and ApplyBQSRSpark tools.
#### Variant Calling: Calls variants using GATK's Mutect2.
#### Variant Filtering: Filters the called variants using GATK's FilterMutectCalls to retain high-confidence variants.
#### Detectability Prediction: Processes the filtered VCF with the vLoD prediction script.
#### Integration of Detectability Status: Integrates the detectability status back into the VCF.
#### MIT Licence

## Contributions
#### Contributions are welcome!
- Fork the repository: This will create a copy of this project in your account.

- Clone the forked repository: This will put the project on your local machine.

- Navigate to the directory: cd project-name

- Please create a new branch: Use a name that succinctly tells what your patch does.

##### Make the necessary changes in your local copy. If you've added code that should be tested, add tests. Update the README to the new branch, if necessary.

- Commit the changes in your local repository.

- Push the branch to your forked repository on GitHub.

- Submit a pull request to the original repository.

##### Ensure any install or build dependencies are removed before the end of the layer when doing a build. Add comments with details of changes to the interface, this includes new environment variables, exposed ports, useful file locations, and container parameters. You may merge the Pull Request once you have the sign-off of the maintainers, or if you do not have permission to do that, you may request the reviewer to merge it for you.

#### Code of Conduct

##### In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to make participation in our project and our community a harassment-free experience for everyone. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances. This Code of Conduct applies both within project spaces and in public spaces when an individual is representing the project or its community. 

##### This Code of Conduct is adapted from the Contributor Covenant, version 1.4

```bash
./path_to_script.sh TUMOR_FASTQ_LEFT TUMOR_FASTQ_RIGHT TUMOR_SAMPLE_NAME [BED_INTERVAL_LIST]
