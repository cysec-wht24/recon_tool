# recon-scripts

A modular, three-stage automated reconnaissance toolkit for bug bounty and web application security assessments. Designed to run efficiently against single targets or bulk scope files, the pipeline takes a raw scope definition to a fully crawled, fuzzed, and vulnerability-scanned output with minimal manual intervention.

> **Disclaimer:** This toolkit is intended for authorized security testing and bug bounty programs only. Always ensure you have explicit permission before scanning any target.

---

## Overview

The toolkit is structured as a sequential three-stage pipeline:

```
prepscope.sh  →  priorityscope.sh  →  crawler.sh
  (Scope)          (Deep Recon)       (Historical)
```

| Script | Role |
|---|---|
| `prepscope.sh` | Subdomain enumeration + alive host probing |
| `priorityscope.sh` | Crawl, directory fuzz, param discovery, Nuclei scan |
| `crawler.sh` | Historical URL collection via Wayback Machine and GAU |

Each script is independently usable but they are designed to chain together — the output of one feeds naturally into the next.

---

## Prerequisites

### Required Tools

Ensure the following are installed and accessible in your `$PATH` (or configured within the scripts):

**Stage 1 — `prepscope.sh`**
- [subfinder](https://github.com/projectdiscovery/subfinder) — passive subdomain enumeration
- [httpx](https://github.com/projectdiscovery/httpx) — HTTP probing for live host detection

**Stage 2 — `priorityscope.sh`**
- [katana](https://github.com/projectdiscovery/katana) — headless web crawler with JS execution
- [ffuf](https://github.com/ffuf/ffuf) — fast web fuzzer for directory discovery
- [arjun](https://github.com/s0md3v/Arjun) — HTTP parameter discovery tool
- [nuclei](https://github.com/projectdiscovery/nuclei) — template-based vulnerability scanner
- [jq](https://stedolan.github.io/jq/) — JSON processor (for parsing ffuf/arjun output)
- [SecLists](https://github.com/danielmiessler/SecLists) at `/usr/share/seclists/`

**Stage 3 — `crawler.sh`**
- [katana](https://github.com/projectdiscovery/katana)
- [waybackurls](https://github.com/tomnomnom/waybackurls)
- [gau](https://github.com/lc/gau) — GetAllURLs (Wayback Machine + OTX + Common Crawl)

### Installation (Go-based tools)

```bash
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/lc/gau/v2/cmd/gau@latest
```

---

## Input Formats

All three scripts accept the same flexible input formats:

| Format | Example | Notes |
|---|---|---|
| Single URL | `https://example.com` | Direct target |
| Text file | `targets.txt` | One domain/URL per line; supports wildcard entries (`*.example.com`) |
| CSV file | `targets.csv` | Domain/URL extracted from the first column; header row skipped |

---

## Usage

### Stage 1 — Scope Preparation (`prepscope.sh`)

Enumerates subdomains for wildcard scope entries and probes all targets for live HTTP(S) hosts. Produces a clean `master_targets.txt` file ready for the next stage.

```bash
chmod +x prepscope.sh
./prepscope.sh <url | targets.txt | targets.csv>
```

**Example:**
```bash
./prepscope.sh scope.txt
```

**Output structure:**
```
<run_name>/<date>/
├── subdomains/        # Raw subfinder output per domain
├── alive/             # Live hosts per domain (httpx output)
└── master_targets.txt # Deduplicated list of all live targets
```

Wildcard entries (e.g., `*.example.com`) are automatically expanded via `subfinder`, while direct URLs are probed immediately with `httpx`. Both are merged into a single master list at the end.

---

### Stage 2 — Priority Scope Deep Recon (`priorityscope.sh`)

The core recon stage. For each live target it performs headless crawling, directory fuzzing, parameter discovery, and automated vulnerability scanning.

```bash
chmod +x priorityscope.sh
./priorityscope.sh <url | targets.txt | master_targets.txt>
```

**Example (chained from Stage 1):**
```bash
./priorityscope.sh example_com/2024-01-01/master_targets.txt
```

**What it does, per target:**

1. **Headless crawl** with Katana (depth 3, JS execution, XHR tracking, static asset filtering)
2. **URL cleaning** — strips static assets (images, fonts, CSS), extracts JS files and parameterized URLs separately
3. **Directory fuzzing** with FFUF using SecLists `common.txt` (recursive, depth 2, rate-limited to 20 req/s)
4. **Parameter discovery** with Arjun on all URLs containing query parameters
5. **URL merging** — combines Katana, FFUF, and Arjun results into a single deduplicated list
6. **Vulnerability scanning** with Nuclei against the merged URL set

**Nuclei coverage includes:** CVEs, exposed tokens/secrets, admin panels, RCE, SQLi, XSS, SSRF, LFI, open redirects, cloud misconfigs (AWS, GCP, Kubernetes, Docker), CORS, JWT issues, API/GraphQL endpoints, and subdomain takeovers — filtered to medium, high, and critical severity.

**Output structure:**
```
<run_name>/<target>/
├── katana_raw_<date>.txt       # Raw crawl results
├── urls_clean_<date>.txt       # Filtered, deduped URLs
├── js_files_<date>.txt         # Extracted JavaScript file URLs
├── param_urls_<date>.txt       # URLs with query parameters
├── ffuf_dirs_<date>.json       # FFUF raw JSON output
├── ffuf_urls_<date>.txt        # FFUF discovered URLs
├── arjun_<date>.json           # Arjun raw JSON output
├── arjun_urls_<date>.txt       # Arjun-discovered parameterized URLs
├── all_urls_<date>.txt         # Final merged URL list
└── nuclei_<date>.jsonl         # Nuclei findings (JSONL format)
```

---

### Stage 3 — Historical URL Collection (`crawler.sh`)

Collects historical URLs from the Wayback Machine and other public archives using `waybackurls` and `gau`. Useful for discovering forgotten endpoints, legacy parameters, and decommissioned paths that may still be accessible.

```bash
chmod +x crawler.sh
./crawler.sh <url | targets.txt | targets.csv>
```

**Example:**
```bash
./crawler.sh https://example.com
./crawler.sh targets.txt
```

This script can be run independently at any point — it does not depend on Stage 1 or Stage 2 output.

**Output structure:**
```
scans/<run_name>/<target>/
├── katana_standard_<date>.txt  # Live crawl output (depth 3, JS-enabled)
└── historical_<date>.txt       # Deduplicated Wayback + GAU URLs
```

---

## Full Pipeline Example

```bash
# 1. Prepare and enumerate scope
./prepscope.sh scope.txt

# 2. Run deep recon on all live targets
./priorityscope.sh bugbounty_target/2024-10-15/master_targets.txt

# 3. Collect historical URLs (can run in parallel with stage 2)
./crawler.sh scope.txt
```

---

## Design Decisions

- **Rate limiting** is enforced across all tools (Katana: 15 req/s, FFUF: 20 req/s, Nuclei: 20 req/s) to stay within responsible disclosure norms and avoid triggering WAFs.
- **`X-Bug-Bounty` header** is injected in all active requests to identify traffic to program security teams.
- **`set -euo pipefail`** is used throughout for strict error handling; individual tool failures are isolated with `|| true` so a single failing target doesn't abort a bulk run.
- All outputs are **date-stamped** to support repeated runs and diff-based change tracking over time.
- Nuclei templates are **auto-updated** at the start of each `priorityscope.sh` run to ensure coverage of the latest CVEs.

---

## License

This project is intended for authorized security research and bug bounty programs. The author is not responsible for misuse.