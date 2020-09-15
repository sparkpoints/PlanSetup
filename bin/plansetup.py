import os
import argparse
import configparser
import logging
from datetime import datetime 

# system config
SystemConfigFile = "config.ini"
PlanTemplateFile = "plantemplate.ini"
# ScriptBinHome = SystemScriptHome + 'bin/'
# ScriptTempDir = SystemScriptHome + 'tmp/'
# ScriptLogDir = SystemScriptHome + 'log/'

# # def config or template file
# BeamTemplate = SystemScriptHome + 'BeamTemplate.txt'
# IMRTTemplate = SystemScriptHome + 'IMrTTemplate.txt'

#logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logpath = "./log.log"
fh = logging.FileHandler(logpath)
fh.setLevel(logging.WARN)
fmt = "%(asctime)-15s %(levelname)s %(filename)s %(lineno)d %(process)d %(message)s"
datefmt = "%a %d %b %Y %H:%M:%S"
formatter = logging.Formatter(fmt, datefmt)
fh.setFormatter(formatter)
logger.addHandler(fh)



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

    logger.debug('debug message')
    logger.info('info message')
    logger.warning('warn message')
    logger.error('error message')
    logger.critical('critical message')

    config2 = configparser.ConfigParser()
    config2.read(PlanTemplateFile,encoding='utf-8')
    print(config2.sections())
    print(config2.get('BEAMs','VMAT'))




