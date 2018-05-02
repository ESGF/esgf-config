#!/bin/bash -e

# Description
#   This script publishes mapfiles.
#   Processes by dataset.

# --------- arguments & initialization --------- #

while [ "${1}" != "" ]; do
    case "${1}" in
        "--project")         shift; project="${1}"       ;;
        "--dataset_pattern") shift; input_dataset="${1}" ;;
        "--script-dir")      shift; scripts_path="${1}"  ;;
        "--worker-log")      shift; LOGFILE="${1}"       ;;
    esac
    shift
done

source ${scripts_path}/functions.sh

# INI files directory
ESGCET_PATH="/esg/config/esgcet/"
# Indexnode hostname
MYPROXY_HOST="esgf-node.com"
# myproxy-logon port
MYPROXY_PORT="7512"
# Publisher's openID login registered
MYPROXY_LOGIN="synda_<INSTITUTE>"
# Publisher's openID password
MYPROXY_PASSWD="xxxxxxxx"
# Root path
ROOT_PATH="/your/data/path"
# Mapfile directory
MAP_DIR="/your/mapfiles/path"

# --------- main --------- #

msg "INFO" "publication.sh started"
msg "INFO" "Input: ${input_dir}"

# Loads ESGF publisher environment
source /usr/local/conda/bin/activate esgf-pub

# Checkup directories and temporary files
if [ ! -d ${ESGCET_PATH} ]; then
    msg "ERROR" "${ESGCET_PATH} does not exist. STOP." >&2
    exit 1
fi
if [ ! -d ${HOME}/.globus ]; then
    msg "ERROR" "${HOME}/.globus does not exist. STOP." >&2
    exit 1
fi
if [ -f ${HOME}/.globus/certificate-file ]; then
    msg "WARNING" "${HOME}/.globus/certificate-file already exists. Deleted." >&2
    rm -f ${HOME}/.globus/certificate-file
fi

# Retrieve mapfile name with an esgprep dry run
uuid=$(uuidgen)
esgprep mapfile -i ${ESGCET_PATH} \
                --project ${project,,} \
                --outdir /tmp/map \
                --no-checksum \
                --mapfile "{dataset_id}.{version}.${uuid}" \
                ${input_dir} 1>&2 2> /dev/null
mapfile_orig=$(find /tmp/map/ -type f | grep "${uuid}")
mapfile=$(basename ${mapfile_orig} | sed "s|\.${uuid}|\.map|g")
rm -fr ${mapfile_orig}

# Gets proxy certificates for publication
msg "INFO"  "Get ESGF certificates..."
cat ${MYPROXY_PASSWD_FILE} | myproxy-logon -b -T -s ${MYPROXY_HOST} -p ${MYPROXY_PORT} -l ${MYPROXY_LOGIN} -o ${HOME}/.globus/certificate-file -S

# Initialize node and controlled vocabulary
esginitialize -c -i ${ESGCET_PATH}

msg "INFO"  "Unpublishing ${mapfile} if exists..."
# Unpublication
esgunpublish -i ${ESGCET_PATH} \
             --project ${project,,} \
             --database-delete \
             --delete \
             --no-republish \
             --map ${mapfile_dir}${mapfile}
msg "INFO"  "Publishing ${mapfile} on datanode PostgreSQL..."
# Datanode publication
esgpublish -i ${ESGCET_PATH} \
           --project ${project,,} \
           --test \
           --set-replica \
           --service fileservice \
           --map ${mapfile_dir}${mapfile}
msg "INFO"  "Publishing ${mapfile} on datanode THREDDS..."
# Datanode publication
esgpublish -i ${ESGCET_PATH} \
           --project ${project,,} \
           --test \
           --set-replica \
           --thredds \
           --noscan \
           --service fileservice \
           --map ${mapfile_dir}${mapfile}
msg "INFO"  "Publishing ${mapfile} on indexnode Solr..."
#Indexnode publication
esgpublish -i ${ESGCET_PATH} \
           --project ${project,,} \
           --test \
           --set-replica \
           --publish \
           --noscan \
           --service fileservice \
           --map ${mapfile_dir}${mapfile}

msg "INFO" "publication.sh complete"

# Deactivate publisher env
source deactivate
