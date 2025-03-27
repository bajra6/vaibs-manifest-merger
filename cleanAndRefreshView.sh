#!/bin/bash


echo "========================================================================================================="
echo "As a prerequisite for running the PMC script, we clean and refresh the label. Should a new label be released withing the few moments of refreshing view and running PMC, dear human, I'm sorry :("
echo "========================================================================================================="

echo "Running command - cd $AVR"
cd $AVR
echo "Running command - ade cleanview"
ade cleanview
echo "Running command - ade refreshview -latest"
ade refreshview -latest