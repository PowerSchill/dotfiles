
#!/usr/bin/env zsh

# ============================================================================
# Terraform Functions
# ============================================================================

# Initialize Terraform with tfswitch
function tfinit() {
    if command -v tfswitch &>/dev/null; then
        tfswitch || return 1
    fi

    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    terraform init "$@"
}

# Plan with optional output file
function tfplan() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    if command -v grc &>/dev/null; then
        grc terraform plan -out="$plan_file" | tee /dev/tty
    else
        terraform plan -out="$plan_file"
    fi
}

# Apply Terraform plan
function tfapply() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    if [[ ! -f "$plan_file" ]]; then
        echo "Error: Plan file '$plan_file' not found"
        echo "Run 'tfplan' first to generate a plan"
        return 1
    fi

    terraform apply "$plan_file"
}

# Validate Terraform configuration
function tfvalidate() {
    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    terraform fmt -check -recursive . && terraform validate
}

# Format Terraform files
function tffmt() {
    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    terraform fmt -recursive "${1:-.}"
}

# Terraform destroy with confirmation
function tfdestroy() {
    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    echo "⚠️  WARNING: This will destroy all resources managed by Terraform"
    echo -n "Type 'yes' to confirm: "
    read -r response

    if [[ "$response" != "yes" ]]; then
        echo "Destroy cancelled"
        return 1
    fi

    terraform destroy "$@"
}

# Manage Terraform workspaces
function tfworkspace() {
    if ! command -v terraform &>/dev/null; then
        echo "Error: terraform is not installed"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        terraform workspace list
    else
        terraform workspace "$@"
    fi
}

# Clean Terraform cache
function tfpurge() {
    local dir="${1:-.}"
    local count
    count=$(find "$dir" -type d -name ".terraform" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$count" -eq 0 ]]; then
        echo "No .terraform directories found in $dir"
        return 0
    fi

    echo "Found $count .terraform director(y|ies) to remove"
    echo -n "Continue? [y/N] "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        find "$dir" -type d -name ".terraform" -prune -exec rm -rf {} \;
        echo "✓ Cleaned .terraform directories"
    else
        echo "Cancelled"
        return 1
    fi
}

# ============================================================================
# Terragrunt Functions
# ============================================================================

# Initialize Terragrunt
function tginit() {
    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    terragrunt init "$@"
}

# Plan with Terragrunt
function tgplan() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    terragrunt init || return 1

    if command -v grc &>/dev/null; then
        grc terragrunt plan -out="$plan_file"
    else
        terragrunt plan -out="$plan_file"
    fi
}

# Apply Terragrunt plan
function tgapply() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    if [[ ! -f "$plan_file" ]]; then
        echo "Error: Plan file '$plan_file' not found"
        echo "Run 'tgplan' first to generate a plan"
        return 1
    fi

    terragrunt apply "$plan_file"
}

# Validate Terragrunt configuration
function tgvalidate() {
    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    terragrunt validate "$@"
}

# Run-all init
function tginitall() {
    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    terragrunt run-all init "$@"
}

# Run-all plan with filtered output
function tgplanall() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    echo "Initializing all modules..."
    tginitall || return 1

    echo -e "\nPlanning all modules..."
    terragrunt run-all plan -out="$plan_file" 2>&1 | \
        grep -ivE 'Refreshing state\.\.\.|Reading\.\.\.|Read complete after|Failed to download module|msg=Executing hook|^\s*$'
}

# Run-all apply
function tgapplyall() {
    local plan_file="${1:-tfplan.out}"

    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    # Check if at least one plan file exists
    if ! find . -name "$plan_file" -type f 2>/dev/null | grep -q .; then
        echo "Error: No plan files found"
        echo "Run 'tgplanall' first to generate plans"
        return 1
    fi

    echo "⚠️  WARNING: This will apply changes across all Terragrunt modules"
    echo -n "Type 'yes' to confirm: "
    read -r response

    if [[ "$response" != "yes" ]]; then
        echo "Apply cancelled"
        return 1
    fi

    terragrunt run-all apply "$plan_file"
}

# Run-all destroy with confirmation
function tgdestroyall() {
    if ! command -v terragrunt &>/dev/null; then
        echo "Error: terragrunt is not installed"
        return 1
    fi

    echo "⚠️  WARNING: This will DESTROY all resources across all Terragrunt modules"
    echo -n "Type 'yes' to confirm: "
    read -r response

    if [[ "$response" != "yes" ]]; then
        echo "Destroy cancelled"
        return 1
    fi

    terragrunt run-all destroy "$@"
}

# Clean Terragrunt cache
function tgpurge() {
    local dir="${1:-.}"
    local count
    count=$(find "$dir" -type d -name ".terragrunt-cache" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$count" -eq 0 ]]; then
        echo "No .terragrunt-cache directories found in $dir"
        return 0
    fi

    echo "Found $count .terragrunt-cache director(y|ies) to remove"
    echo -n "Continue? [y/N] "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        find "$dir" -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;
        echo "✓ Cleaned .terragrunt-cache directories"
    else
        echo "Cancelled"
        return 1
    fi
}

# Clean both Terraform and Terragrunt caches
function tfgpurgeall() {
    tfpurge "$@" && tgpurge "$@"
}
