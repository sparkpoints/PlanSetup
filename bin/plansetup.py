import os
import argparse
import configparser
from datetime import datetime 

# # difine system base dir
# PatientDataHome = "/pinnacle_patient_expansion/NewPatients/"
SystemConfigFile = "config.ini"
# ScriptBinHome = SystemScriptHome + 'bin/'
# ScriptTempDir = SystemScriptHome + 'tmp/'
# ScriptLogDir = SystemScriptHome + 'log/'

# # def config or template file
# BeamTemplate = SystemScriptHome + 'BeamTemplate.txt'
# IMRTTemplate = SystemScriptHome + 'IMrTTemplate.txt'

def digitaltimenow():
    return datetime.now().strftime("%Y%m%d_%H%M%S")

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument('mrn',  help='medical record number')
    parser.add_argument('name', help='patient Name')
    parser.add_argument('plan', help='plan name')
    parser.add_argument('path', help='plan data path')
    args = parser.parse_args()
    
    print(args.mrn,args.name,args.plan,args.path)
    # def temp and log file
    print(digitaltimenow())
    # print(ScriptBinHome,ScriptTempDir)
    
    #get config parameters
    config = configparser.ConfigParser()
    config.read(SystemConfigFile,encoding='utf-8')

    PatientDataHome = config.get('path', 'PatientDataHome')
    SystemScriptHome = config.get('path','SystemScriptHome')
    ScriptBinHome = config.get('path', 'ScriptBinHome')
    ScriptTempDir = config.get('path', 'ScriptTempDir')
    ScriptLogDir  = config.get('path', 'ScriptLogDir')
    print(ScriptLogDir)
    print(config.sections())
    print(config.options('path'))




