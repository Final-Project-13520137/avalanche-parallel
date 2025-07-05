#!/bin/bash

# Function to show help
show_help() {
    echo "🚀 Avalanche Parallel DAG Script Runner"
    echo "===================================="
    echo ""
    echo "📋 Kategori Script yang Tersedia:"
    echo ""
    echo "📦 deployment  - Script untuk deployment dan restart"
    echo "⚙️ setup       - Script untuk setup dan konfigurasi"
    echo "📊 benchmark   - Script untuk benchmark dan testing performa"
    echo "🧹 maintenance - Script untuk pembersihan dan maintenance"
    echo "📈 scaling     - Script untuk scaling dan node management"
    echo "🧪 testing     - Script untuk testing dan validasi"
    echo "🔧 utility     - Script utility dan helper"
    echo ""
    echo "💡 Contoh penggunaan:"
    echo "   ./scripts/run.sh deployment"
    echo "   ./scripts/run.sh deployment deploy-docker.sh --build --workers 3"
    echo "   ./scripts/run.sh benchmark run_parallel_benchmark.sh --full-test"
    echo "   ./scripts/run.sh maintenance cleanup-all.sh"
}

# Function to show scripts in a category
show_scripts() {
    local category_path="$1"
    local category="$2"
    
    if [ ! -d "$category_path" ]; then
        echo "❌ Kategori tidak ditemukan: $category_path"
        return 1
    fi
    
    local scripts=($(find "$category_path" -maxdepth 1 -type f | sort))
    
    if [ ${#scripts[@]} -eq 0 ]; then
        echo "ℹ️ Tidak ada script dalam kategori ini"
        return 0
    fi
    
    echo "📜 Script yang tersedia dalam kategori '$category':"
    echo ""
    
    for script in "${scripts[@]}"; do
        local filename=$(basename "$script")
        local extension="${filename##*.}"
        local icon=""
        
        case "$extension" in
            "ps1") icon="🟦" ;;
            "sh") icon="🟩" ;;
            "go") icon="🔷" ;;
            "bat") icon="🟨" ;;
            *) icon="📄" ;;
        esac
        
        echo "   $icon $filename"
    done
    
    echo ""
    echo "💡 Untuk menjalankan script:"
    echo "   ./scripts/run.sh $category <nama-script> [arguments]"
}

# Function to run a script
run_script() {
    local category_path="$1"
    local script_name="$2"
    shift 2
    local args=("$@")
    
    local script_path="$category_path/$script_name"
    
    if [ ! -f "$script_path" ]; then
        echo "❌ Script tidak ditemukan: $script_path"
        echo ""
        show_scripts "$category_path" "$(basename "$category_path")"
        return 1
    fi
    
    echo "🚀 Menjalankan: $script_path"
    if [ ${#args[@]} -gt 0 ]; then
        echo "📝 Arguments: ${args[*]}"
    fi
    echo ""
    
    local extension="${script_name##*.}"
    
    case "$extension" in
        "ps1")
            if command -v pwsh &> /dev/null; then
                pwsh "$script_path" "${args[@]}"
            elif command -v powershell &> /dev/null; then
                powershell "$script_path" "${args[@]}"
            else
                echo "⚠️ PowerShell tidak ditemukan untuk menjalankan script .ps1"
                return 1
            fi
            ;;
        "sh")
            chmod +x "$script_path" 2>/dev/null
            bash "$script_path" "${args[@]}"
            ;;
        "go")
            if command -v go &> /dev/null; then
                go run "$script_path" "${args[@]}"
            else
                echo "⚠️ Go tidak ditemukan untuk menjalankan script .go"
                return 1
            fi
            ;;
        "bat")
            if command -v cmd &> /dev/null; then
                cmd /c "$script_path ${args[*]}"
            else
                echo "⚠️ cmd tidak ditemukan untuk menjalankan script .bat"
                return 1
            fi
            ;;
        *)
            echo "⚠️ Tidak tahu cara menjalankan file dengan ekstensi: $extension"
            return 1
            ;;
    esac
}

# Main logic
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

category="$1"
script_name="$2"
shift 2
args=("$@")

# Validate category
case "$category" in
    "deployment"|"setup"|"benchmark"|"maintenance"|"scaling"|"testing"|"utility")
        ;;
    *)
        echo "❌ Kategori tidak valid: $category"
        echo ""
        show_help
        exit 1
        ;;
esac

category_path="scripts/$category"

if [ -z "$script_name" ]; then
    show_scripts "$category_path" "$category"
else
    run_script "$category_path" "$script_name" "${args[@]}"
fi 