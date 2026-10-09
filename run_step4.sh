#!/bin/bash

TRACE="602.gcc_s-1850B.champsimtrace.xz"
SIZES=(10 11 12 13 14)
LABELS=("1K" "2K" "4K" "8K" "16K")

for i in "${!SIZES[@]}"; do
    BITS=${SIZES[$i]}
    LABEL=${LABELS[$i]}
    PRED_NAME="bimodal_${LABEL}"
    
    echo "=========================================="
    echo " Configuring $LABEL entries (TABLE_BITS = $BITS)"
    echo "=========================================="
    
    # Generate the predictor file with the specific table size
    cat << CCODE > branch/${PRED_NAME}.bpred
#include <cstdint>
#include <cstdlib>
#include "ooo_cpu.h"

#define TABLE_BITS ${BITS}
#define TABLE_ENTRIES (1 << TABLE_BITS)

uint8_t pht[NUM_CPUS][TABLE_ENTRIES];

void O3_CPU::initialize_branch_predictor()
{
    for (uint32_t i = 0; i < TABLE_ENTRIES; i++)
        pht[cpu][i] = 2; // Weakly Taken
}

uint8_t O3_CPU::predict_branch(uint64_t ip)
{
    uint32_t index = ip & (TABLE_ENTRIES - 1);
    return (pht[cpu][index] >= 2) ? 1 : 0;
}

void O3_CPU::last_branch_result(uint64_t ip, uint8_t taken)
{
    uint32_t index = ip & (TABLE_ENTRIES - 1);
    uint8_t state = pht[cpu][index];

    if (taken) {
        if (state < 3) pht[cpu][index] = state + 1;
    } else {
        if (state > 0) pht[cpu][index] = state - 1;
    }
}
CCODE

    # Compile binary
    ./build_champsim.sh ${PRED_NAME} no no no no lru 1
    
    # Run simulation (10M warmup, 10M sim)
    ./run_champsim.sh ${PRED_NAME}-no-no-no-no-lru-1core 10 10 ${TRACE}
done
