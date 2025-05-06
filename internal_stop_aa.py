#!/usr/bin/env python3
import sys
import os

def clean_fasta(infile):
    # Derive output filename
    base, ext = os.path.splitext(infile)
    if not ext:
        ext = ".fasta"
    outfile = f"{base}.clean{ext}"

    removed_ids = []
    kept_records = []

    seq_id = None
    seq_lines = []

    with open(infile) as fin:
        for line in fin:
            line = line.rstrip()
            if not line:
                continue
            if line.startswith('>'):
                # Process previous record
                if seq_id is not None:
                    seq = ''.join(seq_lines)
                    if '*' in seq[:-1]:
                        removed_ids.append(seq_id)
                    else:
                        kept_records.append((seq_id, seq))
                # Start new record
                seq_id = line[1:].split()[0]
                seq_lines = []
            else:
                seq_lines.append(line)
        # Last record
        if seq_id is not None:
            seq = ''.join(seq_lines)
            if '*' in seq[:-1]:
                removed_ids.append(seq_id)
            else:
                kept_records.append((seq_id, seq))

    # Print IDs of removed sequences
    for rid in removed_ids:
        print(rid)

    # Write cleaned FASTA
    with open(outfile, 'w') as fout:
        for rid, seq in kept_records:
            fout.write(f">{rid}\n")
            # wrap at 60 chars per line
            for i in range(0, len(seq), 60):
                fout.write(seq[i:i+60] + "\n")

    # Optionally inform the user
    print(f"\nSaved {len(kept_records)} sequences to '{outfile}'. Removed {len(removed_ids)} sequences.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} <protein_fasta_file>")
    clean_fasta(sys.argv[1])

