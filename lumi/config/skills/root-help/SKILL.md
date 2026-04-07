---
name: root-help
description: Help with ROOT, RDataFrame, PyROOT, and RooFit code patterns and common tasks
---

## What I do

Provide guidance on writing and debugging ROOT/PyROOT code for HEP analysis.

## Common patterns I can help with

### RDataFrame basics
```python
import ROOT
df = ROOT.RDataFrame("tree_name", "file.root")
df = df.Filter("nJets >= 4")
df = df.Define("mll", "sqrt(2*pt1*pt2*(cosh(eta1-eta2)-cos(phi1-phi2)))")
h = df.Histo1D(("mll", ";m_{ll} [GeV];Events", 100, 0, 200), "mll")
h.Draw()
```

### Reading multiple files
```python
df = ROOT.RDataFrame("tree", ["file1.root", "file2.root"])
# or with a glob via a TChain
chain = ROOT.TChain("tree")
chain.Add("/eos/atlas/path/*.root")
df = ROOT.RDataFrame(chain)
```

### Proper histogram ownership
```python
f = ROOT.TFile.Open("out.root", "RECREATE")
h = ROOT.TH1F("h", "title", 100, 0, 1)
h.SetDirectory(f)  # attach to file
# or for transient histograms:
h.SetDirectory(0)  # detach from any file
```

### Luminosity weighting
```python
weight = xsec_pb * 1000 * kfactor * filteff / sumOfWeights * luminosity_fb
df = df.Define("totalWeight", f"mcWeight * {weight}")
```

### Enable multithreading
```python
ROOT.EnableImplicitMT()  # call BEFORE creating RDataFrame
```

## Tips
- Always call `EnableImplicitMT()` before creating any RDataFrame
- Use `Snapshot` to save filtered/modified data to new ROOT files
- Use `GetValue()` or `Draw()` to trigger lazy evaluation
- For debugging, use `.Display(columns, nrows).Print()` to inspect data
