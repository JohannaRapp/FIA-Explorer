# FIA Explorer V3
Analysis of flow-injection time-of-flight mass spectrometry (FI-MS) data:
import mzXML files, reduce each injection to one spectrum, annotate the peaks
against a metabolite database, browse the result, and export it to Excel.


## Requirements
- MATLAB R2019b or newer
- Bioinformatics Toolbox (`msresample`, `msbackadj`)
- Signal Processing Toolbox (`findpeaks`)

mzXML files are read by `Step 1 Load/read_mzxml.m`.
It needs the JVM only for compressed files.


## Installation
1. Convert the raw FI-TOF data to `.mzXML` with MSConvert, using the settings
   in `Settings_MSConvert_FIA.PNG`.
2. Right-click this folder in MATLAB, choose
   *Add to Path > Selected Folders and Subfolders*.
3. Run the app:

   ```matlab
   FiaExplorer_V3
   ```
Example Data and a Video how to use the software can be found here:
https://doi.org/10.5281/zenodo.22144227

## Naming your raw files

File names need some metadata and must look like this:

```
<sample>_<position(plate-well)>_<polarity>.mzXML
```

for example `aroC_P6-A1_pos.mzXML`. The polarity tag is `pos` or `neg`

## Using the app

| Menu | What it does |
|---|---|
| **Load > Raw Data** | Select mzXML files, annotate them, save a FIA file |
| **Load > FIA File** | Reopen a saved FIA file |
| **Annotation** | Re-annotate the open data set against another database |
| **Export > Fia-Data** | Write an Excel workbook |
| **Export > To Workspace** | Copy the open data set into the base workspace as `fia_data` |

Clicking a row in the *Annotation* tab zooms the plot to that ion's expected
mass and draws every sample in black, with the peak used in each sample
marked. The *Samples* tab highlights one sample in red. The **Zoom** slider
sets the width of the mass window and redraws immediately.

## How to access the data (fia_data)

```matlab
% 1. the menu: Export > To Workspace
%    puts a copy in the base workspace as fia_data


% 2. from the saved file, which holds one variable, also called fia_data
load('20260904_FIA-File_myrun.mat', 'fia_data')
```


## Using it as a script

Every step is a plain function, so a whole analysis can run without the GUI:

```matlab
params  = fia_default_params();
fiaData = import_raw_data(params);                          % prompts for files
fiaData = annotate_peaks(fiaData, params, 'db_ecmdb.mat');  % no dialog
export_fia_data(fiaData, 'raw', 'C:\results\myrun.xlsx');   % no dialog
```

To change the patameters:

```matlab
params = fia_default_params();
params.minPeakHeight    = 2000;   % more sensitive peak picking
params.massTolerancePpm = 5;      % widen the window for heavy ions
params.adductsPositive  = {'[M+H]+', '[M+Na]+'};
```

Run `adduct_definitions` with no output to list every supported adduct name.



## Export to Excel creates

| Sheet | Contents |
|---|---|
| `pos`, `neg` | identity columns, then one column per sample |
| `pos_detected`, `neg_detected` | same shape, 1 where the value came from a real picked peak and 0 where it was imputed |
| `Database` | database, versions, dates and the full parameter set used |

The identity columns are `abbr`, `MetName`, `mass` and `kegg` and:

- **`adduct`** — the adduct on its own, rather than only as a name suffix
- **`nIsobars`** — how many database entries fall within the mass tolerance of
  this one. `1` means the annotation is unambiguous 
- **`deltaMz_mDa`** — median mass error in mDa
- **`nDetected`** — in how many samples a real peak was found


## The FIA file

Saved as a `.mat` with one variable, `fia_data`: a 1×2 struct, index 1
positive polarity and index 2 negative. 

| Field | Contents |
|---|---|
| `polarity` | `"positive"` or `"negative"` |
| `mz` | shared m/z grid, 1×N |
| `int` | intensities, nSamples×N (single precision) |
| `files`, `samples`, `positions` | per-sample provenance |
| `sampleLabels` | unique per-sample label used as column headings |
| `annot` | the annotation table (see above), plus `Ydata` and `detected` |
| `peakID` | grid index of the peak used, per annotation and sample |
| `database` | database file used |
| `params` | the parameter struct the data were processed with |




## Databases

| File | Entries | Source |

| `db_iML1515merged.mat` | 802 | *E. coli* model, Monk et al. 2017, Nature Biotechnology (isobars merged), metabolites > 50 Da are deleted, because they are not measured in FI-MS |

Code has been optimized with Claude Code Opus 5.
