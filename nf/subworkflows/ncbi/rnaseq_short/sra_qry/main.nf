#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { merge_params } from '../../utilities'

sra_api_url = "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/runinfo"

workflow sra_query  {
    take:
        query
        parameters
    main:
        String params = merge_params("", parameters, "sra_query")
        if (query) {
            params = merge_params(params, ["sra_query" : "-query '${query}'"], "sra_query")
        }
        run_sra_query(params)

    emit:
        sra_metadata = run_sra_query.out.sra_metadata
        sra_run_list = run_sra_query.out.sra_run_list
}

process run_sra_query {
    input:
        val parameters
    output:
        path './sra_metadata.dat', emit: 'sra_metadata'
        path './sra_run_accessions.ids', emit: 'sra_run_list'

    script:
    """
    #!/usr/bin/env python3

    import csv
    import json
    import math
    import shlex
    from urllib.request import urlopen
    from urllib.parse import quote
    from sys import exit

    esearch_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&retmode=json&retmax=10000&idtype=gi&term="
    runinfo_url = "https://trace.ncbi.nlm.nih.gov/Traces/sra-db-be/runinfo?retmode=csv&sp=runinfo&uid="
    TAB = chr(9)
    NL = chr(10)

    parameters = shlex.split("$parameters")
    if len(parameters) < 2 and parameters[0] != "-query":
        exit(1)

    full_query = parameters[1]
    terms = full_query.replace("OR", " ").replace("[Accession]", "").split()

    def chunk_list(lst, n):
        for i in range(0, len(lst), n):
            yield lst[i:i + n]

    all_ids = []
    for chunk in chunk_list(terms, 100):
        chunk_query = ' OR '.join([f"{x}[Accession]" for x in chunk])
        url = esearch_url + quote(chunk_query)
        with urlopen(url) as response:
            esearch_json = json.load(response)
            all_ids.extend(esearch_json["esearchresult"]["idlist"])

    uids = ','.join(all_ids)
    runinfo = urlopen(runinfo_url + uids)
    runinfo_csv = runinfo.read().decode("utf-8")

    lines = runinfo_csv.split(NL)
    header = lines[0]
    keypos = {k: i for i, k in enumerate(header.split(","))}

    sra_meta_keys = ["SRA run accession", "SRA sample accession", "Run type", "SRA read count", "SRA base count", "Average insert size", "Insert size stdev",
                     "Platform type", "Model", "SRA Experiment accession", "SRA Study accession", "Biosample accession", "Bioproject ID", "Bioproject Accession", "Scientific name", "TaxID", "Release date"]

    with open("sra_metadata.dat", 'wt') as outf:
        print(f"#{TAB.join(sra_meta_keys)}", file=outf)
        for line in lines[1:]:
            line = line.strip()
            if not line:
                continue
            for l in csv.reader([line], quotechar='"', delimiter=',', quoting=csv.QUOTE_ALL, skipinitialspace=True):
                parts = l
            printable = []
            paired = False
            for k in ["Run", "Sample", "LibraryLayout", "spots", "bases", "NA", "NA", "Platform", "Model", "Experiment", "SRAStudy", "BioSample", "ProjectID", "BioProject", "ScientificName", "TaxID", "ReleaseDate"]:
                if k not in keypos:
                    printable.append("NA")
                    continue
                v = parts[keypos[k]]
                if k == "LibraryLayout":
                    if parts[keypos["LibraryLayout"]] == "PAIRED":
                        printable.append("paired")
                        paired = True
                    else:
                        printable.append("unpaired")
                elif k == "spots":
                    if not paired:
                        printable.append(v)
                    else:
                        i = int(v)
                        if 'spots_with_mates' in keypos:
                            i += int(parts[keypos['spots_with_mates']])
                        printable.append(str(i))
                else:
                    printable.append(v)
            print(TAB.join(printable), file=outf)

    with open("sra_run_accessions.ids", 'wt') as outf:
        print("#SRA run accession", file=outf)
        for line in lines[1:]:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            run_acc = parts[keypos["Run"]]
            if not run_acc:
                continue
            print(run_acc, file=outf)
    """

    stub:
    """
    touch sra_metadata.dat
    touch sra_run_accessions.ids
    """
}

