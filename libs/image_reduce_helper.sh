#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.2
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################


optimize_image_size() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_max_width}
  # $4 = ${img_max_height}

  local path=$1
  local file_extension=$2
  local img_max_width=$3
  local img_max_height=$4

  local last_run

  # Run ImageMagick mogrify
  log_event "info" "Running mogrify to optimize image sizes ..." "true"

  last_run=$(check_last_optimization_date)
  
  if [[ "${last_run}" == "never" ]]; then
  
    echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;">>$LOG
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;
  
  else
  
    echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;">>$LOG
    ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;
  
  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

optimize_images() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_compress}

  local path=$1
  local file_extension=$2
  local img_compress=$3

  local last_run

  last_run=$(check_last_optimization_date)

  if [ "${file_extension}" == "jpg" ]; then

    # Run jpegoptim
    log_event "info" "Running jpegoptim to optimize images ..." "true"

    if [[ "${last_run}" == "never" ]]; then

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;">>$LOG
      ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    else

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;">>$LOG
      ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    fi

  elif [ "${file_extension}" == "png" ]; then

    # Run optipng
    log_event "info" "Running optipng to optimize images ..." "true"

    if [[ "${last_run}" == "never" ]]; then
    
      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;">>$LOG
      ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    else

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;">>$LOG
      ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    fi

  else

    log_event "warning" "Unsopported file extension ${file_extension}" "true"    

  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

optimize_pdfs() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_max_width}
  # $4 = ${img_max_height}

  local last_run

  last_run=$(check_last_optimization_date)

  # Run pdf optimizer
  log_event "error" "TODO: Running pdfwrite ..." "true"    

  #Here is a solution for getting the output of find into a bash array:
  #array=()
  #while IFS=  read -r -d $'\0'; do
  #    array+=("$REPLY")
  #done < <(find . -name "${input}" -print0)
  #for %f in (*) do gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=%f %f
  #find -mtime -7 -type f -name "*.pdf" -exec gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.3 -dPDFSETTINGS=/screen -dNOPAUSE -dPrinted=false -dQUIET -sOutputFile=compressed.%f %f

}
