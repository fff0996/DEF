"""Original diagrams for three independent functions; uses real example outputs."""
from pathlib import Path
import shutil
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/images"
plt.rcParams.update({"font.family": "DejaVu Sans", "svg.fonttype": "none"})


def box(ax, x, y, w, h, title, detail, color="#197c91"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.07", facecolor="white", edgecolor=color, linewidth=1.7))
    ax.text(x+.17, y+h-.35, title, fontsize=13, color=color, weight="bold")
    ax.text(x+.17, y+h-.75, detail, va="top", fontsize=10, linespacing=1.65)


def save(fig, name):
    fig.savefig(OUT / f"{name}.png", dpi=180, bbox_inches="tight")
    fig.savefig(OUT / f"{name}.svg", bbox_inches="tight")
    plt.close(fig)


fig, ax = plt.subplots(figsize=(14, 7))
fig.patch.set_facecolor("#f5f8fc")
ax.set(xlim=(0, 14), ylim=(0, 7)); ax.axis("off")
ax.text(.2, 6.65, "RTpred | Three independent applications", fontsize=23, weight="bold", color="#16324f")
box(ax,.3,4.25,3.6,1.6,"Bundled default models","Local RP / HILIC best ensemble\nNo GitHub access at runtime")
box(ax,5.05,4.25,3.9,1.6,"01  Default prediction","Compound SMILES -> predicted RT\nStandalone prediction service")
box(ax,.3,1.2,3.6,2,"02  User model training","SMILES + measured RT\nLocal pyRetip / AutoGluon workflow\nTrain / validation / reserved test")
box(ax,5.05,1.2,3.9,2,"User model bundles","Saved models + selected best\nDescriptor / runtime manifest\nReserved evaluation compounds")
box(ax,10,1.2,3.7,2,"03  Model comparison","Default best + user candidates\nSame evaluation compounds\nRMSE / MAE / R-squared")
for start,end in [((3.97,5.05),(4.95,5.05)),((3.97,2.15),(4.95,2.15)),((9.05,2.15),(9.9,2.15))]:
    ax.annotate("",xy=end,xytext=start,arrowprops={"arrowstyle":"->","lw":2,"color":"#197c91"})
ax.annotate("",xy=(11.7,3.3),xytext=(2.1,4.15),arrowprops={"arrowstyle":"->","lw":1.6,"color":"#d78437","connectionstyle":"angle,angleA=0,angleB=90,rad=8"})
ax.text(9.4,3.8,"default best",fontsize=10,color="#b26620")
ax.text(.3,.5,"Module 1 does not depend on user training. Module 3 consumes models and measured evaluation data, not module 1 output.",fontsize=11,color="#4c6174")
save(fig,"pipeline_flow")

concepts = [
    ("module1_concept", "01 | Default best-model prediction", [
        ("Compound input", "CSV / XLSX\nSMILES + RP / HILIC\nMeasured RT optional"),
        ("Local best ensemble", "RDKit features\nWeightedEnsemble_L3\nExplicit saved-best selection"),
        ("Predicted RT", "One result per input row\nInvalid structures retained\nCSV + QC + distribution")]),
    ("module2_concept", "02 | Train a user-specific retention time model", [
        ("Measured library", "SMILES + measured RT\nGroup by canonical structure\nReserve test compounds first"),
        ("Train and select", "Fit feature filter on train only\nLocal pyRetip training interface\nBest selected by validation RMSE"),
        ("Reusable models", "AutoGluon models + manifest\nTraining structure hashes\nUnused reserved test CSV")]),
    ("module3_concept", "03 | Compare default and user models", [
        ("Common evaluation set", "SMILES + measured RT\nCheck user training overlap\nSame valid rows for all models"),
        ("Models to compare", "Bundled default best\nOne or more user bundles\nAll candidates or each best"),
        ("Performance comparison", "RMSE / MAE / R-squared\nRank table + paired RT plot\nDefault remains unchanged")])]
for name,title,boxes in concepts:
    fig,ax=plt.subplots(figsize=(14,4.5));fig.patch.set_facecolor("#f5f8fc")
    ax.set(xlim=(0,14),ylim=(0,4.5));ax.axis("off")
    ax.text(.25,4.0,title,fontsize=22,weight="bold",color="#16324f")
    for i,(heading,detail) in enumerate(boxes):
        box(ax,.3+i*4.65,1.05,4.05,2.25,heading,detail)
        if i<2:ax.annotate("",xy=(4.82+i*4.65,2.1),xytext=(4.43+i*4.65,2.1),arrowprops={"arrowstyle":"->","lw":2,"color":"#197c91"})
    ax.text(.3,.4,"Original explanatory diagram | No publication figures reproduced | CPU inference/training; no runtime download",fontsize=10,color="#4c6174")
    save(fig,name)

for i,folder,name in [(1,"01_predict","prediction"),(2,"02_train_RP","training"),(3,"03_compare_RP","comparison")]:
    for ext in ["png","svg"]:
        shutil.copy2(ROOT/f"examples/{folder}/{name}.{ext}",OUT/f"module{i}_result.{ext}")
