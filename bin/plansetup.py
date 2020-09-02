import os
import argparse

# difine system base dir
PatientDataHome = "/pinnacle_patient_expansion/NewPatients/"
SystemScriptHome = "/usr/local/adacnew/PinnacleSiteData/Scripts/"
ScriptBinHome = SystemScriptHome + 'bin/'
ScriptTempDir = SystemScriptHome + 'tmp/'
ScriptLogDir = SystemScriptHome + 'log/'

# def config or template file
BeamTemplate = SystemScriptHome + 'BeamTemplate.txt'
IMRTTemplate = SystemScriptHome + 'IMrTTemplate.txt'

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument('mrn',help='medical record number')
    parser.add_argument('path',help='plan data path')
    args = parser.parse_args()
    
    print(args.mrn,args.path)
    # def temp and log file
    
    print(ScriptBinHome,ScriptTempDir)
