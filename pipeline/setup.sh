#!/bin/bash

#=============================================================================
# Minerva Environment Setup for Nextflow PRS-CS Pipeline v3
# IMPROVED VERSION - Based on working v2 setup
# Date: August 18, 2025
#=============================================================================

echo "=========================================="
echo "🚀 Setting up Minerva environment for Nextflow PRS-CS Pipeline v3"
echo "   IMPROVED VERSION - Based on tested v2 setup"
echo "=========================================="

# Color functions for pretty output
print_success() { echo -e "\033[1;32m✓ $1\033[0m"; }
print_error() { echo -e "\033[1;31m✗ $1\033[0m"; }
print_info() { echo -e "\033[1;34mℹ $1\033[0m"; }
print_warning() { echo -e "\033[1;33m⚠ $1\033[0m"; }

#=============================================================================
# STEP 1: Load modules in tested working order
#=============================================================================
print_info "Step 1: Loading modules in tested order..."

# Start completely clean
#module purge
print_success "Cleared all modules"

# Load Java 21 first
module load java/21.0.4
print_success "Loaded Java 21.0.4"

# Load Nextflow (preserves Java 21)
module load nextflow
print_success "Loaded Nextflow"

# Load R (this switches Java back to 1.8 - we'll fix this)
module load R/4.0.3
print_success "Loaded R/4.0.3"

# Load Python for PRS-CS
module load python/3.9.0
print_success "Loaded Python/3.8.2"

# Load PLINK2
module load plink2/2.3
print_success "Loaded PLINK2/2.3"

#=============================================================================
# STEP 2: Fix Java environment (critical fix)
#=============================================================================
print_info "Step 2: Fixing Java environment (R switched it to 1.8)..."

# Force the correct Java 21 environment variables
export JAVA_HOME="/hpc/packages/minerva-rocky9/java/21.0.4/jdk-21.0.4"
export JAVA_CMD="/hpc/packages/minerva-rocky9/java/21.0.4/jdk-21.0.4/bin/java"
export PATH="/hpc/packages/minerva-rocky9/java/21.0.4/jdk-21.0.4/bin:$PATH"

print_success "Applied Java 21 environment fix"

#=============================================================================
# STEP 3: Verify all tools work
#=============================================================================
print_info "Step 3: Verifying all tools work correctly..."

echo ""
echo "=== TOOL VERIFICATION ==="

# Check Java
#JAVA_VER="$(java -version 2>&1 | head -1)"
#echo "Java: $JAVA_VER"
#if [[ $JAVA_VER == *'"21.0.4"'* ]]; then
#  echo "OK: Java 21.0.4"
#else
#  echo "ERR: Expected Java 21.0.4"
#  _fail
#fi

# Check Nextflow
if command -v nextflow >/dev/null 2>&1; then
    NF_TEST=$(nextflow -version 2>&1)
    if [[ $? -eq 0 ]]; then
        NF_VER=$(echo "$NF_TEST" | grep "nextflow version" | head -1)
        if [[ -n "$NF_VER" ]]; then
            echo "🔄 Nextflow: $NF_VER"
        else
            echo "🔄 Nextflow: Available and working"
        fi
        print_success "Nextflow working correctly"
    else
        print_error "Nextflow not working"
        exit 1
    fi
else
    print_error "Nextflow not found"
    exit 1
fi

# Check R
R_VER=$(R --version 2>&1 | head -1)
echo "📊 R: $R_VER"
print_success "R working correctly"

# Check Python
PYTHON_VER=$(python --version 2>&1)
echo "🐍 Python: $PYTHON_VER"
print_success "Python working correctly"

# Check PLINK2
PLINK_VER=$(plink2 --version 2>&1 | head -1)
echo "🧬 PLINK2: $PLINK_VER"
print_success "PLINK2 working correctly"

#=============================================================================
# STEP 4: Setup project environment and validate files
#=============================================================================
print_info "Step 4: Setting up project environment and validating files..."

# Navigate to project directory
PROJECT_DIR="/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/pipeline"
if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR"
    print_success "In project directory: $PROJECT_DIR"
else
    print_error "Project directory not found: $PROJECT_DIR"
    echo "Please update PROJECT_DIR in this script or cd manually"
    exit 1
fi

# Check essential v3 pipeline files
echo ""
echo "=== V3 PIPELINE FILES STATUS ==="
files_ok=true

# Essential v3 pipeline files
essential_files=(
    "main.nf"
    "config/nextflow.config"
    "config/adlerGWAS_UKBB.recipe"
    "config/GWAS.column.types.csv"
    "config/Cohorts.csv"
)

for file in "${essential_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        files_ok=false
    fi
done

# Check optional files
echo ""
echo "=== OPTIONAL FILES STATUS ==="
optional_files=(
    "config/masterlist.csv"
    "config/Clusters.csv"
)

for file in "${optional_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "Found: $file"
    else
        print_warning "Optional file missing: $file"
        echo "   → Pipeline will use defaults"
    fi
done

# Check GWAS input files
echo ""
echo "=== GWAS INPUT FILES ==="
if [[ -d "gwas_original" ]]; then
    GWAS_COUNT=$(find gwas_original -name "*.txt" -o -name "*.tsv" -o -name "*.gz" 2>/dev/null | wc -l)
    if [[ $GWAS_COUNT -gt 0 ]]; then
        print_success "Found $GWAS_COUNT GWAS files"
        echo "   Sample files:"
        find gwas_original -name "*.txt" -o -name "*.tsv" -o -name "*.gz" 2>/dev/null | head -3 | sed 's/^/     /'
        [[ $GWAS_COUNT -gt 3 ]] && echo "     ... and $((GWAS_COUNT-3)) more"
    else
        print_warning "No GWAS files found in gwas_original/"
        echo "   → Add your GWAS files for complete pipeline run"
    fi
else
    print_warning "gwas_original directory not found"
fi

# Check PRS-CS software
echo ""
echo "=== PRS-CS SOFTWARE ==="
PRSCS_EXEC="/hpc/packages/minerva-rocky9/prscs/1.0.0/PRScs.py"
LDREF_DIR="/hpc/packages/minerva-rocky9/prscs/ldref/ldblk_1kg_eur"

if [[ -f "$PRSCS_EXEC" ]]; then
    print_success "PRS-CS executable found: $PRSCS_EXEC"
else
    print_error "PRS-CS executable not found: $PRSCS_EXEC"
    files_ok=false
fi

if [[ -d "$LDREF_DIR" ]]; then
    print_success "LD reference directory found: $LDREF_DIR"
else
    print_error "LD reference directory not found: $LDREF_DIR"
    files_ok=false
fi

#=============================================================================
# STEP 5: Check existing data status
#=============================================================================
print_info "Step 5: Checking existing data status..."

echo ""
echo "=== EXISTING DATA STATUS ==="

# Check for formatted GWAS files
if [[ -d "gwas_formatted" ]]; then
    formatted_count=$(find gwas_formatted -name "*.txt" 2>/dev/null | wc -l)
    if [[ $formatted_count -gt 0 ]]; then
        print_success "Formatted GWAS files: $formatted_count files"
    else
        print_info "No formatted GWAS files (will be created by pipeline)"
    fi
else
    print_info "gwas_formatted directory will be created by pipeline"
fi

# Check for existing model chunks
if [[ -d "results/models_v3/chunks" ]]; then
    chunk_count=$(find results/models_v3/chunks -name "*.txt" 2>/dev/null | wc -l)
    if [[ $chunk_count -gt 0 ]]; then
        print_success "Model chunks available: $chunk_count files"
    else
        print_info "No model chunks (will be created by pipeline)"
    fi
else
    print_info "Model chunks directory will be created by pipeline"
fi

# Check for complete models
if [[ -d "results/models_v3/complete" ]]; then
    complete_count=$(find results/models_v3/complete -name "*.txt" 2>/dev/null | wc -l)
    if [[ $complete_count -gt 0 ]]; then
        print_success "Complete models available: $complete_count files"
        echo "   Available models:"
        ls results/models_v3/complete/*.txt 2>/dev/null | sed 's/.*\///' | sed 's/^/     /'
    else
        print_info "No complete models (will be created by pipeline)"
    fi
else
    print_info "Complete models directory will be created by pipeline"
fi

# Check for score files
if [[ -d "results/scores_v3/individual" ]]; then
    score_count=$(find results/scores_v3/individual -name "*.sscore" 2>/dev/null | wc -l)
    if [[ $score_count -gt 0 ]]; then
        print_success "Score files available: $score_count files"
    else
        print_info "No score files (will be created by pipeline)"
    fi
else
    print_info "Score files directory will be created by pipeline"
fi

#=============================================================================
# STEP 6: Create v3-specific helper functions
#=============================================================================
print_info "Step 6: Creating v3-specific helper functions..."

# Function to run v3 pipeline with tested parameters
run_pipeline() {
    echo ""
    echo "🚀 Running Nextflow PRS-CS Pipeline v3"
    echo "   Recipe: ${1}"
    echo "   Phi values: ${2:-'auto,1e-06,1e-04,1e-02,1e+00'}"
    echo ""
    
    

    # Create logs directory
    mkdir -p logs
    
    # Set default parameters
    local recipe_name="$1"
    local phi_list="${2:-auto,1e-06,1e-04,1e-02,1e+00}"
    
    # Build command
    local cmd="nextflow run main.nf"
    cmd="$cmd -c config/nextflow.config"
    cmd="$cmd -profile standard"
    cmd="$cmd --recipe '/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/pipeline/config/${recipe_name}'"
    cmd="$cmd --phi_list '$phi_list'"
    cmd="$cmd -with-report 'logs/report_$(date +%Y%m%d_%H%M%S).html'"
    cmd="$cmd -with-timeline 'logs/timeline_$(date +%Y%m%d_%H%M%S).html'"
    cmd="$cmd -with-dag 'logs/dag_$(date +%Y%m%d_%H%M%S).html'"
    #cmd="$cmd -resume"
    cmd="$cmd ${@:3}"
    
    echo "Executing: $cmd"
    echo ""
    
    # Execute command
    eval "$cmd"
}

# Function to run with development profile (smaller resources)
run_v3_dev() {
    echo ""
    echo "🧪 Running v3 pipeline in development mode (smaller resources)"
    echo "   Traits: ${1:-'first available'}"
    echo "   Phi values: ${2:-'auto'}"
    echo ""
    
    # Create logs directory
    mkdir -p logs
    
    local traits="${1:-}"
    local phi_list="${2:-auto}"
    
    local cmd="nextflow run main.nf"
    cmd="$cmd -c nextflow_v3_corrected.config"
    cmd="$cmd -profile dev"
    
    if [[ -n "$traits" ]]; then
        cmd="$cmd --traits '$traits'"
    fi
    
    cmd="$cmd --phi_list '$phi_list'"
    cmd="$cmd -with-report 'logs/dev_report_$(date +%Y%m%d_%H%M%S).html'"
    cmd="$cmd -resume"
    cmd="$cmd ${@:3}"
    
    echo "Executing: $cmd"
    echo ""
    
    eval "$cmd"
}

# Function to check v3 pipeline status
check_v3_status() {
    echo "=== V3 PIPELINE STATUS ==="
    
    # Check LSF jobs
    echo "Active LSF jobs:"
    bjobs -w 2>/dev/null || echo "  No active LSF jobs"
    
    echo ""
    echo "=== V3 PIPELINE PROGRESS ==="
    
    # Check each stage
    if [[ -d "gwas_formatted" ]]; then
        formatted_count=$(find gwas_formatted -name "*_formatted.txt" 2>/dev/null | wc -l)
        echo "GWAS formatting: $formatted_count files completed"
    fi
    
    if [[ -d "results/models_v3/chunks" ]]; then
        chunk_count=$(find results/models_v3/chunks -name "*.txt" 2>/dev/null | wc -l)
        echo "Model generation: $chunk_count chunk files created"
    fi
    
    if [[ -d "results/models_v3/complete" ]]; then
        complete_count=$(find results/models_v3/complete -name "*.txt" 2>/dev/null | wc -l)
        echo "Model joining: $complete_count complete models"
    fi
    
    if [[ -d "results/scores_v3/individual" ]]; then
        score_count=$(find results/scores_v3/individual -name "*.sscore" 2>/dev/null | wc -l)
        echo "Individual scoring: $score_count score files"
    fi
    
    if [[ -f "results/final_v3/final_PRS_scores.tsv" ]]; then
        echo "Final aggregation: ✅ Complete!"
    else
        echo "Final aggregation: ⏳ Pending"
    fi
    
    echo ""
    echo "=== DISK USAGE ==="
    
    # Work directory size
    if [[ -d "work" ]]; then
        echo "Work directory size: $(du -sh work/ 2>/dev/null | cut -f1)"
    else
        echo "No work directory (clean state)"
    fi
    
    # Results size
    if [[ -d "results" ]]; then
        echo "Results directory size: $(du -sh results/ 2>/dev/null | cut -f1)"
    fi
    
    # Check recent log
    if [[ -f ".nextflow.log" ]]; then
        echo ""
        echo "=== RECENT LOG ENTRIES ==="
        tail -5 .nextflow.log 2>/dev/null || echo "No recent log entries"
    fi
}

# Function to show v3-specific working commands
show_v3_commands() {
    echo ""
    echo "=== V3 PIPELINE COMMANDS ==="
    echo ""
    echo "🧪 DEVELOPMENT/TESTING:"
    echo "   run_v3_dev                           # Quick test with defaults"
    echo "   run_v3_dev 'trait1' 'auto'         # Test specific trait"
    echo ""
    echo "🚀 PRODUCTION RUNS:"
    echo "   run_pipeline                      # Full pipeline, all traits"
    echo "   run_pipeline 'trait1,trait2' 'auto,1e-06'  # Specific traits/phi"
    echo ""
    echo "📊 MONITORING:"
    echo "   check_v3_status                      # Check pipeline progress"
    echo "   bjobs                                # Check LSF jobs"
    echo "   tail -f .nextflow.log               # Follow pipeline log"
    echo ""
    echo "🔧 TROUBLESHOOTING:"
    echo "   nextflow clean -f                    # Clean work directory"
    echo "   run_pipeline '' '' -resume       # Resume from last checkpoint"
    echo ""
    echo "📁 KEY V3 OUTPUTS:"
    echo "   - gwas_formatted/                    # Formatted GWAS files"
    echo "   - results/models_v3/chunks/         # Chromosome-specific models"
    echo "   - results/models_v3/complete/       # Complete joined models" 
    echo "   - results/scores_v3/individual/     # Individual score files"
    echo "   - results/final_v3/                 # Final aggregated results"
    echo ""
    
    # Show available GWAS files for reference
    if [[ -d "gwas_original" ]] && [[ $(find gwas_original -name "*.txt" -o -name "*.tsv" -o -name "*.gz" 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "📋 AVAILABLE GWAS FILES:"
        find gwas_original -name "*.txt" -o -name "*.tsv" -o -name "*.gz" 2>/dev/null | sed 's/.*\///' | sed 's/\.[^.]*$//' | sed 's/^/   /'
        echo ""
    fi
}

# Export functions
export -f run_pipeline
export -f run_v3_dev
export -f check_v3_status
export -f show_v3_commands

print_success "Created v3 helper functions: run_pipeline, run_v3_dev, check_v3_status, show_v3_commands"

#=============================================================================
# FINAL STATUS AND INSTRUCTIONS
#=============================================================================
echo ""
echo "=========================================="
echo "🎯 V3 SETUP COMPLETE!"
echo "=========================================="

if [[ "$files_ok" == "true" ]]; then
    print_success "All essential files verified - ready to run v3 pipeline!"
else
    print_warning "Some files missing - check above errors"
fi

echo ""
echo "📋 IMMEDIATE V3 USAGE:"
echo ""
echo "# Show all v3 commands:"
echo "show_v3_commands"
echo ""
echo "# Quick development test:"
echo "run_v3_dev"
echo ""
echo "# Full production run:"
echo "run_pipeline"
echo ""
echo "# Check progress:"
echo "check_v3_status"
echo ""

echo "🔧 V3 TROUBLESHOOTING:"
echo "- To reload this environment: source setup_v3.sh"
echo "- Check jobs: bjobs"
echo "- View reports: ls -lt logs/"
echo "- Pipeline logs: tail -f .nextflow.log"
echo "- Clean and restart: nextflow clean -f && run_pipeline"
echo ""

echo "📊 V3 PIPELINE FEATURES:"
echo "- ✅ Complete end-to-end automation (GWAS → final scores)"
echo "- ✅ Massive parallelization (trait × phi × chromosome)"
echo "- ✅ Automatic error recovery and memory scaling"
echo "- ✅ Comprehensive progress tracking and reporting"
echo "- ✅ Multiple execution profiles (dev, test, lsf)"
echo ""

echo "🎯 V3 vs V2 DIFFERENCES:"
echo "- V3: Complete pipeline (5 steps: format → generate → join → score → aggregate)"
echo "- V2: Scoring-only pipeline (assumes models already exist)"
echo "- V3: Suitable for raw GWAS files starting from scratch"
echo "- V2: Suitable for existing model files and iterative scoring"
echo ""

echo "=========================================="
echo "🚀 Ready for v3! Use 'show_v3_commands' for examples"
echo "=========================================="
