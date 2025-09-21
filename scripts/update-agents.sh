#!/usr/bin/env /bin/zsh
# update-agents.sh — recursively edit Markdown files *in place* under claude/agents/**
# Front‑matter rules (first block only):
#  1) Append TAGLINE once to the first `description:` line.
#  2) Model handling
#     • If no `model:` → add `model: <MODEL>` (replace `tools:` if present; else insert after `description:`)
#     • If one or more `model:` → do NOT add another.
#     • De‑duplicate: keep the first non‑default (≠ <MODEL> after normalization),
#       otherwise keep the first; drop the others.
#     • Normalize kept model: if it’s opus/sonnet/haiku and version ≥ configured latest,
#       collapse to family name; otherwise leave as‑is. Always strip trailing -YYYYMMDD.
#
# Latest versions are **configurable** via flags or env so the script keeps working as they change:
#   -O <ver>  latest opus (default from $LATEST_OPUS or 4.1)
#   -S <ver>  latest sonnet (default from $LATEST_SONNET or 4.0)
#   -H <ver>  latest haiku (default from $LATEST_HAIKU or 3.5)
#
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

: ${AGENTS_ROOT:="$PWD/claude/agents"}
: ${MODEL_DEFAULT:="sonnet"}
: ${TAGLINE:="PROACTIVELY use this agent."}
: ${LATEST_OPUS:="4.1"}
: ${LATEST_SONNET:="4.0"}
: ${LATEST_HAIKU:="3.5"}

DRY_RUN=false
VERBOSE=false

while getopts ":nvM:r:O:S:H:" opt; do
  case $opt in
    n) DRY_RUN=true ;;
    v) VERBOSE=true ;;
    M) MODEL_DEFAULT="$OPTARG" ;;
    r) AGENTS_ROOT="$OPTARG" ;;
    O) LATEST_OPUS="$OPTARG" ;;
    S) LATEST_SONNET="$OPTARG" ;;
    H) LATEST_HAIKU="$OPTARG" ;;
    *) print -u2 -- "Unknown option: -$OPTARG"; exit 2 ;;
  esac
done
shift $((OPTIND-1))

if [[ ! -d "$AGENTS_ROOT" ]]; then
  print -u2 -- "Error: AGENTS_ROOT does not exist: $AGENTS_ROOT"
  exit 1
fi

autoload -Uz colors && colors || true
vprint() { $VERBOSE && print -P -- "$@" || true }

print -P "%F{cyan}Scanning recursively under:%f %F{yellow}$AGENTS_ROOT%f"

edit_front_matter_inplace() {
  local file="$1" model="$2" tagline="$3" lopus="$4" lsonnet="$5" lhaiku="$6"
  local dir base tmp
  dir=${file:h}
  base=${file:t}
  tmp="$dir/.${base}.tmp.$$"

  /usr/bin/awk -v MODEL="$model" -v TAGLINE="$tagline" -v LOPUS="$lopus" -v LSONNET="$lsonnet" -v LHAIKU="$lhaiku" '
    function trim(s) { sub(/^[ 	]*/, "", s); sub(/[ 	]*$/, "", s); return s }
    function family_of(s,   t){ t=tolower(s); if (index(t,"opus")) return "opus"; if (index(t,"sonnet")) return "sonnet"; if (index(t,"haiku")) return "haiku"; return "" }
    function latest_for(f){ if (f=="opus") return LOPUS+0; else if (f=="sonnet") return LSONNET+0; else if (f=="haiku") return LHAIKU+0; else return -1 }
    function version_of(s,   tmp,n,i,tok,val,max,arr){
      tmp=s; gsub(/[^0-9.]/, " ", tmp); n=split(tmp, arr, /[ ]+/); max=-1
      for (i=1;i<=n;i++) { tok=arr[i]; if (tok=="") continue; if (tok ~ /^[0-9]+(\.[0-9]+)?$/) { val=tok+0; if (val<100 && val>max) max=val } }
      if (max<0) return ""; return max
    }
    function strip_date_suffix(s){ sub(/-[0-9]{8}$/, "", s); return s }
    function normalize_value(val,   fam,ver,latest){
      val=trim(val); fam=family_of(val); ver=version_of(val)
      if (fam!="") { latest=latest_for(fam); if (ver!="" && ver>=latest) return fam; }
      return val
    }

    BEGIN { capturing=0; fmDelims=0 }

    # Start buffering at first --- line
    capturing==0 && $0 ~ /^[ 	]*---[ 	]*$/ {
      capturing=1; fmDelims=1; n=0; fm[++n]=$0; next
    }

    # While buffering FM
    capturing==1 {
      fm[++n]=$0
      if ($0 ~ /^[ 	]*---[ 	]*$/) {
        fmDelims++
        if (fmDelims==2) {
          # Scan FM for indices/values
          desc_i=0; tools_i=0; k=0
          for (i=1;i<=n;i++) {
            line=fm[i]
            if (i>1 && i<n) {
              if (line ~ /^[ 	]*model[ 	]*:/) { k++; model_idx[k]=i; val=line; sub(/^[ 	]*model[ 	]*:[ 	]*/, "", val); model_val[k]=trim(val) }
              else if (desc_i==0 && line ~ /^[ 	]*description[ 	]*:/) { desc_i=i }
              else if (tools_i==0 && line ~ /^[ 	]*tools[ 	]*:/) { tools_i=i }
            }
          }

          # Append tagline once
          if (desc_i>0) {
            dline=fm[desc_i]; if (index(dline, TAGLINE)==0) fm[desc_i]=dline " " TAGLINE
          }

          # Add model if absent
          if (k==0) {
            if (tools_i>0) {
              fm[tools_i] = "model: " MODEL
            } else if (desc_i>0) {
              # insert after description line
              n_new=0
              for (i=1;i<=n;i++) { out[++n_new]=fm[i]; if (i==desc_i) out[++n_new] = "model: " MODEL }
              n=n_new; for (x in fm) delete fm[x]; for (i=1;i<=n;i++) fm[i]=out[i]; for (x in out) delete out[x]
            }
          }

          # Re-scan models after potential insert
          k=0; for (i=1;i<=n;i++) if (i>1 && i<n && fm[i] ~ /^[ 	]*model[ 	]*:/) { k++; model_idx[k]=i; val=fm[i]; sub(/^[ 	]*model[ 	]*:[ 	]*/, "", val); model_val[k]=trim(val) }

          if (k>=1) {
            # Normalize values for default comparison
            for (mi=1; mi<=k; mi++) { norm_val[mi]=normalize_value(model_val[mi]); is_default[mi]=(tolower(norm_val[mi])==tolower(MODEL))?1:0 }

            # Choose which model line to keep
            keep_idx=0; keep_mi=0
            if (k>=2) {
              chosen=0
              for (mi=1; mi<=k; mi++) if (is_default[mi]==0) { keep_idx=model_idx[mi]; keep_mi=mi; chosen=1; break }
              if (!chosen) { keep_idx=model_idx[1]; keep_mi=1 }
              for (mi=1; mi<=k; mi++) { if (model_idx[mi] != keep_idx) fm[ model_idx[mi] ] = "" }
            } else { keep_idx=model_idx[1]; keep_mi=1 }

            # Finalize kept model line
            fam=family_of(model_val[keep_mi]); ver=version_of(model_val[keep_mi]); latest=latest_for(fam)
            if (fam!="" && ver!="" && ver>=latest) new_value=fam; else new_value=model_val[keep_mi]
            new_value=strip_date_suffix(new_value)
            fm[keep_idx] = "model: " new_value
          }

          # Compact removed lines and print FM
          n2=0; for (i=1;i<=n;i++) if (fm[i] != "") out[++n2]=fm[i]
          for (i=1;i<=n2;i++) print out[i]
          for (x in fm) delete fm[x]; for (x in out) delete out[x]
          capturing=0; fmDelims=0
          next
        }
      }
      next
    }

    { print $0 }
  ' "$file" > "$tmp"

  if $DRY_RUN; then
    rm -f -- "$tmp"
  else
    /bin/mv -f -- "$tmp" "$file"
  fi
}

/usr/bin/find "$AGENTS_ROOT" -type f -name '*.md' -print0 |
while IFS= read -r -d '' f; do
  base=${f:t}
  [[ $base == README.md ]] && { vprint "%F{8}skip%f $f"; continue; }
  vprint "%F{blue}→ edit%f $f"
  edit_front_matter_inplace "$f" "$MODEL_DEFAULT" "$TAGLINE" "$LATEST_OPUS" "$LATEST_SONNET" "$LATEST_HAIKU"
done

print -P "%F{green}✓ Completed front matter edits under $AGENTS_ROOT.%f"

