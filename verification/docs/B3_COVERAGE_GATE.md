# B3 – Coverage merge gate

merge_coverage.py exits 1 if unique GPIO bins < 5.
chip-regress calls it after pyuvm-regress.
