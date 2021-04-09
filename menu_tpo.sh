#!/bin/bash

### FUNCTIONS ############################

: 'function showUsage {
   echo "Usage : menu_tpo.sh
                   
                    -s <servers_list_filename_number_choice>
                    -e <servers_exceptions_list_filename_number_choice>
                    -d -> Do not display nslookup, nc, exceptions and status
                    -b -> Display ssh connections messages (errors, warnings, motd...)
                    -h -> To display help
                    
                    -m <menu 1 choice> : 
                    
                        1. function_loop (generates csv result file)
                        
                            -n <menu 2 choice> :
                            
                                1. function_run_ssh_command
                                    -t <command>
                                2. function_run_remote_script
                                    -r <remote_script_filename_number_choice>
                                3. function_transfer_remote_zip_and_run_ssh_command
                                    -z <remote_zip_filename_number_choice>        
                                
                        2. function_run_ssh_command
                            -t <command>
                        3. function_run_remote_script
                            -r <remote_script_filename_number_choice>
                        4. function_transfer_remote_zip_and_run_ssh_command
                            -z <remote_zip_filename_number_choice>"       
}
'

function showUsage {
   echo "Usage : menu_tpo.sh
                   
                    -s <servers_list_filename_number_choice>
                    -e <servers_exceptions_list_filename_number_choice>
                    -d -> Do not display nslookup, nc, exceptions and status
                    -b -> Display ssh connections messages (errors, warnings, motd...)
                    -h -> To display help
                    
                    -m <menu 1 choice> : 
                    
                        1. function_loop (generates csv result file)
                        
                            -n <menu 2 choice> :
                            
                                1. function_run_ssh_command
                                    -t <command>
                                2. function_run_remote_script
                                    -r <remote_script_filename_number_choice>       
                                
                        2. function_run_ssh_command
                            -t <command>
                        3. function_run_remote_script
                            -r <remote_script_filename_number_choice>"    
}

##### VARIABLES #####

USER_SSH_RHEL7="XXXX"

# 0 -> Don't display name server
# 1 -> Display name server
display_name_server=1

## SSH COMMANDS LIST FILENAME
ssh_commands_list_filename="ssh_commands_list.txt"
 
## PATH VARIABLES
remote_script_path="remote_scripts/"
servers_exceptions_lists_path="servers_exceptions_lists/"
servers_lists_path="servers_lists/"
remote_zip_path="remote_zip/"

## COLORS VARIABLES
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
PINK='\033[35m'
CYAN='\033[36m'
END='\033[0m'

## RESULTS VARIABLES
results_csv_path="results_csv/"
results_csv_filename="results_csv_file_$(date +%Y%m%d%H%M%S).csv"
results_csv_path_and_filename="$results_csv_path/$results_csv_filename"

# 0 -> Display just remote_script_result and ssh_command_result / par défaut si on ne met rien (ça fait none donc comme si 0 dans le script)
# 1 -> Display all log infos (needed for display results of nc, check site, exception list and nslookup checks)
display_log_full="1"

# 0 -> Display ssh messages
# 1 -> Don't display ssh messages
display_ssh_messages="0"  # Par défaut on ne veut pas car ça affiche dans le résulat des logs de connexion qui ne nous intéressent pas


function recuperer_options {
   while getopts "m:n:s:z:r:e:t:dbh" argument   # Si on ne met pas ":" derrière la lettre c'est qu'on ne require pas un argument 
   do
    case ${argument} in
    m)      
           menu1_arg=${OPTARG}
	   ;;
 	n)
           menu2_arg=${OPTARG}
	   ;;
	s)
           servers_list_filename_number_choice_arg=${OPTARG}
	   ;;
	z)
           remote_zip_filename_number_choice_arg=${OPTARG}
	   ;;
	r)
           remote_script_filename_number_choice_arg=${OPTARG}
	   ;;
	e)
           servers_exceptions_list_filename_number_choice_arg=${OPTARG}
	   ;;
  	t)
           ssh_command_arg=${OPTARG}
	   ;;
	d)
           display_log_full="0"
	   ;;
	b)
           display_ssh_messages="1"
	   ;;
	h)     showUsage
           exit 0
	   ;;
     esac
   done
}

recuperer_options "$@"


function function_loop {
    # Lancer une action en boucle

    function_x=$1
    echo -e "${FUNCNAME[0]} -> $function_x"

    if [ "$function_x" == "function_run_remote_script" ]
        then
            function_choose_remote_script_filename
            function_choose_servers_list_filename
            function_choose_servers_exceptions_list_filename        
            echo "hostname;Is it an exceptions ?;nslookup status;netcat port 22 status;Remote script status;Remote script details;Remote script result" >> $results_csv_path_and_filename
            for server in $(cat $servers_list_path_and_filename)
            do
                # init des variables pour le csv
                check_if_server_in_exceptions_list_status=""
                check_if_server_in_exceptions_list_status_details=""
                check_nslookup_status=""
                check_nc_status=""
                run_remote_script_status="";
                run_remote_script_status_details="";
                run_remote_script_result="";
                
                [[ $display_name_server -eq 1 ]] && echo -e "\n${YELLOW} --- $server --- ${END}\n"
                
               function_check_if_server_in_exceptions_list $server
               if [ "$check_if_server_in_exceptions_list_status" == "Is not in exception list" ]
                   then
                       function_check_nslookup $server
                       if [ "$check_nslookup_status" == "OK" ]
                           then
                                function_check_nc $server
                                if [ "$check_nc_status" == "OK" ]
                                    then
                                        $function_x $server
                                fi
                       fi
               fi
               
                if [ "$check_if_server_in_exceptions_list_status" == "Is in exception list" ]
                    then
                        echo  "$server;$check_if_server_in_exceptions_list_status;$check_nslookup_status;$check_nc_status;$run_remote_script_status;$run_remote_script_status_details;\"$check_if_server_in_exceptions_list_status_details\";" >> $results_csv_path_and_filename
                    else
                        echo  "$server;$check_if_server_in_exceptions_list_status;$check_nslookup_status;$check_nc_status;$run_remote_script_status;$run_remote_script_status_details;\"$run_remote_script_result\";" >> $results_csv_path_and_filename
                fi
            done
    fi
    
    if [ "$function_x" == "function_run_ssh_command" ]
        then
            function_choose_ssh_commands_list_filename
            function_choose_servers_list_filename
            function_choose_servers_exceptions_list_filename        
            echo "hostname;Is it an exceptions ?;Exception details;nslookup status;netcat port 22 status;SSH command status;SSH command details;SSH command connexion;SSH command result" >> $results_csv_path_and_filename
            for server in $(cat $servers_list_path_and_filename)
            do
                # init des variables pour le csv
                check_if_server_in_exceptions_list_status=""
                check_if_server_in_exceptions_list_status_details=""
                check_nslookup_status=""
                check_nc_status=""
                run_ssh_command_status="";
                run_ssh_command_status_details="";
                ssh_run_command_only_for_ssh_errors_result="";
                ssh_run_command_result="";
                
                [[ $display_name_server -eq 1 ]] && echo -e "\n${YELLOW} --- $server --- ${END}\n"
                
                function_check_if_server_in_exceptions_list $server
                if [ "$check_if_server_in_exceptions_list_status" == "Is not in exception list" ]
                    then
                        function_check_nslookup $server
                        if [ "$check_nslookup_status" == "OK" ]
                            then
                                function_check_nc $server
                                if [ "$check_nc_status" == "OK" ]
                                    then
                                        $function_x $server
                                fi
                        fi
                fi
                
                echo "$server;$check_if_server_in_exceptions_list_status;$check_if_server_in_exceptions_list_status_details;$check_nslookup_status;$check_nc_status;$run_ssh_command_status;$run_ssh_command_status_details;\"$ssh_run_command_only_for_ssh_errors_result\";\"$ssh_run_command_result\";" >> $results_csv_path_and_filename 
            done
    fi
    
    if [ "$function_x" == "function_run_perso_script" ]
        then
            function_choose_servers_list_filename
            function_choose_servers_exceptions_list_filename        
            echo "hostname;Is it an exceptions ?;nslookup status;netcat port 22 status;Exit code" >> $results_csv_path_and_filename
            for server in $(cat $servers_list_path_and_filename)
            do
                # init des variables pour le csv
                check_if_server_in_exceptions_list_status=""
                check_if_server_in_exceptions_list_status_details=""
                check_nslookup_status=""
                check_nc_status=""
                run_perso_script_return_code="";
                exit_code="";
                
                [[ $display_name_server -eq 1 ]] && echo -e "\n${YELLOW} --- $server --- ${END}\n"
                
               function_check_if_server_in_exceptions_list $server
               if [ "$check_if_server_in_exceptions_list_status" == "Is not in exception list" ]
                   then
                       function_check_nslookup $server
                       if [ "$check_nslookup_status" == "OK" ]
                           then
                                function_check_nc $server
                                if [ "$check_nc_status" == "OK" ]
                                    then
                                        $function_x $server
                                        run_perso_script_return_code=$?
                                        [[ $display_log_full -eq 1 ]] && echo -e "\n${function_x} : Return code = $run_perso_script_return_code"
                                fi
                       fi
               fi
               
                if [ "$check_if_server_in_exceptions_list_status" == "Is in exception list" ]
                    then
                        echo  "$server;$check_if_server_in_exceptions_list_status;$check_nslookup_status;$check_nc_status;$exit_code" >> $results_csv_path_and_filename
                    else
                        echo  "$server;$check_if_server_in_exceptions_list_status;$check_nslookup_status;$check_nc_status;$run_perso_script_return_code;" >> $results_csv_path_and_filename
                fi
            done
    fi
    
     if [ "$function_x" == "function_transfer_remote_zip_and_run_ssh_command" ]
        then
            function_choose_remote_zip_filename
            function_choose_ssh_commands_list_filename
            function_choose_servers_list_filename
            function_choose_servers_exceptions_list_filename        
            echo "hostname;Is it an exceptions ?;Exception details;nslookup status;netcat port 22 status;transfer zip status;SSH command status;SSH command details" >> $results_csv_path_and_filename
            for server in $(cat $servers_list_path_and_filename)
            do
                # init des variables pour le csv
                check_if_server_in_exceptions_list_status=""
                check_if_server_in_exceptions_list_status_details=""
                check_nslookup_status=""
                check_nc_status=""
                transfer_remote_zip_status="";
                run_ssh_command_status="";
                run_ssh_command_status_details="";
                
                [[ $display_name_server -eq 1 ]] && echo -e "\n${YELLOW} --- $server --- ${END}\n"
                
                function_check_if_server_in_exceptions_list $server
                if [ "$check_if_server_in_exceptions_list_status" == "Is not in exception list" ]
                    then
                        function_check_nslookup $server
                        if [ "$check_nslookup_status" == "OK" ]
                            then
                                function_check_nc $server
                                if [ "$check_nc_status" == "OK" ]
                                    then
                                        function_transfer_remote_zip $server
                                        function_run_ssh_command $server
                                fi
                        fi
                fi
                echo "$server;$check_if_server_in_exceptions_list_status;$check_if_server_in_exceptions_list_status_details;$check_nslookup_status;$check_nc_status;$transfer_remote_zip_status;$run_ssh_command_status;$run_ssh_command_status_details;" >> $results_csv_path_and_filename
            done
    fi
}


function function_check_nc {
    # Test nc du port 22

    server=$1   
    
    # check_nc_result=$(nc -v -z -w 1 ${server}-a 22 2>&1)
    check_nc_result=$(nc -w 1 $server 22 2>&1)
    check_nc_return_code=$?
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_return_code = $check_nc_return_code"
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_result : $check_nc_result"   
    
    if [ "$check_nc_return_code" == "0" ]
        then
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}netcat port 22 OK${END}"
            check_nc_status="OK"
            
            # Vérification type os
            # echo "nc result : $check_nc_result"
            check_nc_ostype_result=$(echo $check_nc_result | grep "OpenSSH_7" 2>&1 >/dev/null)
            check_nc_ostype_return_code=$?
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_ostype_return_code = $check_nc_ostype_return_code"
            if [ "$check_nc_ostype_return_code" == "0" ]
                then
                    ostype="rhel7"
                else
                    ostype="rhel6"
            fi
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ostype = $ostype" 
        else
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}netcat port 22 KO${END}"
            check_nc_status="KO"
            
            # On test si -a repond
            check_nc_result=$(nc -w 1 ${server}-a 22 2>&1)
            check_nc_return_code=$?
            
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_return_code = $check_nc_return_code"
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_result : $check_nc_result"
            if [ "$check_nc_return_code" == "0" ]
                then
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}netcat port 22 admin OK${END}"
                    server=$server-a
                    check_nc_status="OK"
                    
                    # Vérification type os
                    # echo "nc result : $check_nc_result"
                    check_nc_ostype_result=$(echo $check_nc_result | grep "OpenSSH_7" 2>&1 >/dev/null)
                    check_nc_ostype_return_code=$?
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nc_ostype_return_code = $check_nc_ostype_return_code"
                    if [ "$check_nc_ostype_return_code" == "0" ]
                        then
                            ostype="rhel7"
                        else
                            ostype="rhel6"
                    fi
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ostype = $ostype" 

                else
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}netcat port 22 admin KO${END}"
                    check_nc_status="KO"
            fi      
    fi  
}


function function_check_nslookup {
    # Test nslookup

    server=$1
    
    check_nslookup_result=$(nslookup $server) 2>&1
    check_nslookup_return_code=$?
    check_nslookup_result_modified="$(echo $check_nslookup_result | grep Address)"
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nslookup_return_code = $check_nslookup_return_code"
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : check_nslookup_result : $check_nslookup_result_modified"
    if [ "$check_nslookup_return_code" == "0" ]
        then
	    is_moba=$(env | grep MOBA | wc -l)
            [[ $is_moba -eq 0 ]] && check_nslookup_ip=$(nslookup $server | awk 'NR==5 { print $2}') || check_nslookup_ip=$(nslookup $server | awk 'NR==3 { print $3}') # Pour l'exécution depuis un serveur linux ou Moba
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}nslookup OK -> $check_nslookup_ip${END}"
            check_nslookup_status="OK"
        else
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}nslookup KO${END}"
            check_nslookup_status="KO"
    fi
}


function function_check_if_server_in_exceptions_list {
    # Tester si exception

    server=$1   

    check_if_server_in_exceptions_list_result=$(grep -i $server $servers_exceptions_list_path_and_filename)
    check_if_server_in_exceptions_list_return_code=$?
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : Return code = $check_if_server_in_exceptions_list_return_code"
    if [ "$check_if_server_in_exceptions_list_result" != "" ]
        then
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : Result -> $check_if_server_in_exceptions_list_result"
            check_if_server_in_exceptions_list_status_details=$(grep -i $server $servers_exceptions_list_path_and_filename | cut -d ';' -f 2)
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : Exception details -> $check_if_server_in_exceptions_list_status_details"
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : \"$server\" IS in exception list \"$servers_exceptions_list_filename\""
            check_if_server_in_exceptions_list_status="Is in exception list"
        else
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : Result -> Grep did not find \"$server\" in \"$servers_exceptions_list_path_and_filename\""
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : \"$server\" IS NOT in exception list \"$servers_exceptions_list_filename\""
            check_if_server_in_exceptions_list_status="Is not in exception list"
    fi
}


function function_run_remote_script {
    # SCP remote script et executer sur le distant

    server=$1 
    
    if [[ $ostype == "rhel7" ]]
        then
            scp_upload_script_command="scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -r $remote_script_path_and_filename $USER_SSH_RHEL7@$server:~/"
            ssh_run_remote_script_command="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo bash $remote_script_filename"
        else
            scp_upload_script_command="scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -r $remote_script_path_and_filename root@$server:/tmp/"
            ssh_run_remote_script_command="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes root@$server bash /tmp/$remote_script_filename"
    fi
    
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : SCP remote script"    
    run_scp_remote_script_result=$($scp_upload_script_command 2>&1) 2>&1
    run_scp_remote_script_return_code=$? 
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_scp_remote_script_return_code = $run_scp_remote_script_return_code"
    if [[ $run_scp_remote_script_return_code == "0" ]]
        then
            if [[ $display_ssh_messages == "0" ]]
                then
                    [[ $log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_result without error display"
                    run_remote_script_result=$($ssh_run_remote_script_command 2> /dev/null)
                    run_remote_script_return_code=$? 
                else
                    [[ $log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_result with error display"
                    run_remote_script_result=$($ssh_run_remote_script_command 2>&1)
                    run_remote_script_return_code=$? 
            fi                 
            
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_return_code = $run_remote_script_return_code"
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_result : \n\n$run_remote_script_result\n" || echo -e "\n\n$run_remote_script_result\n"
            
            run_remote_script_status='The return code is not known'
            run_remote_script_status_details='The return code is not known'
            [[ $run_remote_script_return_code -eq 1 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Remote script or ssh connexion KO'
            [[ $run_remote_script_return_code -eq 254 ]] && run_remote_script_status="KO" && run_remote_script_status_details='ssh connexion KO'
            [[ $run_remote_script_return_code -eq 127 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Script not found'
            [[ $run_remote_script_return_code -eq 0 ]] && run_remote_script_status="OK" && run_remote_script_status_details='Remote script OK'
            [[ $run_remote_script_return_code -eq 70 ]] && run_remote_script_status="KO" && run_remote_script_status_details='All routes KO'
            [[ $run_remote_script_return_code -eq 71 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Route 1 KO'
            [[ $run_remote_script_return_code -eq 72 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Route 2 KO'
            [[ $run_remote_script_return_code -eq 73 ]] && run_remote_script_status="OK" && run_remote_script_status_details='All routes OK'
            [[ $run_remote_script_return_code -eq 80 ]] && run_remote_script_status="KO" && run_remote_script_status_details='chkconfig KO'
            [[ $run_remote_script_return_code -eq 81 ]] && run_remote_script_status="OK" && run_remote_script_status_details='chkconfig OK'
            [[ $run_remote_script_return_code -eq 82 ]] && run_remote_script_status="OK" && run_remote_script_status_details='gateway KO'
            [[ $run_remote_script_return_code -eq 6 ]] && run_remote_script_status="KO" && run_remote_script_status_details='No IP configured ?'
            [[ $run_remote_script_return_code -eq 2 ]] && run_remote_script_status="KO" && run_remote_script_status_details='No such file or directory ?'
            [[ $run_remote_script_return_code -eq 90 ]] && run_remote_script_status="OK" && run_remote_script_status_details='Rear OK (deja installe et volumetrie conforme). Il reste le configurer pour le nouveau besoin de patching.'
            [[ $run_remote_script_return_code -eq 91 ]] && run_remote_script_status="OK" && run_remote_script_status_details='Yum OK mais Rear KO (mal installe ou volumetrie non conforme).'
            [[ $run_remote_script_return_code -eq 92 ]] && run_remote_script_status="OK" && run_remote_script_status_details='Yum OK et volumetrie OK mais Rear non installe.'
            [[ $run_remote_script_return_code -eq 93 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Yum KO et Rear KO (mal installe ou volumetrie non conforme).'
            [[ $run_remote_script_return_code -eq 94 ]] && run_remote_script_status="KO" && run_remote_script_status_details='Install REAR KO.'    
            
            if [ "$run_remote_script_status" == "KO" ] || [ "$run_remote_script_status" == "The return code is not known" ]
                then
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}$run_remote_script_status -> $run_remote_script_status_details${END}"
                    run_remote_script_status_details="$run_remote_script_status_details"
                else
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}$run_remote_script_status -> $run_remote_script_status_details${END}"
                    run_remote_script_status_details="$run_remote_script_status_details"
            fi
        else
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_scp_remote_script_result : \n\n$run_scp_remote_script_result\n" || echo -e "\n\n$run_scp_remote_script_result\n"
            run_remote_script_result=$run_scp_remote_script_result
            run_remote_script_status="KO - Error transfer SCP"
    fi
}

function function_transfer_remote_zip {
    # SCP remote zip

    server=$1   
    
    scp_upload_zip_command="scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -r $remote_zip_path_and_filename root@$server:/tmp/"
    transfer_remote_zip_result=$($scp_upload_zip_command) 2>&1
    transfer_remote_zip_return_code=$?
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : transfer_remote_zip_return_code = $transfer_remote_zip_return_code"
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : transfer_remote_zip_result : \n\n$transfer_remote_zip_result\n" || echo -e "\n\n$transfer_remote_zip_result\n"
    
    transfer_remote_zip_status='The return code is not known'
    transfer_remote_zip_status_details='The return code is not known'
    [[ $transfer_remote_zip_return_code -eq 0 ]] && transfer_remote_zip_status="OK" && transfer_remote_zip_status_details='Remote zip OK'    
    
    if [ "$transfer_remote_zip_status" == "KO" ] || [ "$transfer_remote_zip_status" == "The return code is not known" ]
        then
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}$transfer_remote_zip_status -> $transfer_remote_zip_status_details${END}"
            transfer_remote_zip_status_details="$transfer_remote_zip_status_details"
        else
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}$transfer_remote_zip_status -> $transfer_remote_zip_status_details${END}"
            transfer_remote_zip_status_details="$transfer_remote_zip_status_details"
    fi  
}

function function_choose_remote_zip_filename {

    echo -e "\n${CYAN}Zip files available (You are free to add new zip files to \"$remote_zip_path\" directory) :${END}\n" 
    ls $remote_zip_path | nl -s ": "
    echo
    if [ -z "$remote_zip_filename_number_choice_arg" ]
        then
            read -e -p "remote_zip_filename number ? : " remote_zip_filename_number_choice
        else
            read -e -p "remote_zip_filename number ? : " remote_zip_filename_number_choice <<< $remote_zip_filename_number_choice_arg
    fi 
    echo -e "\nOption chosen above : $remote_script_filename_number_choice\n"
    remote_zip_filename=$(ls $remote_zip_path | nl -s ": " | grep -e " $remote_zip_filename_number_choice:" | awk '{print $2}')
    remote_zip_path_and_filename=$remote_zip_path$remote_zip_filename
}


function function_run_perso_script {

    server=$1 
    if [ ! -d "perso_results/$server" ];then mkdir -p "perso_results/$server"; fi
    perso_files_path="perso_files/"
    CHEM_DEST_RHEL6="/tmp/tempo_test"
    CHEM_DEST_RHEL7="/home/benjo/tempo_test"
    file1="lanceur_audit_oracle_rhel6.bash"
    file2="ReviewNG1.1.sql"
    file3="lanceur_audit_oracle_rhel7.bash"
    
    echo ""
    
    if [[ $ostype == "rhel7" ]]
        then
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo mkdir -p $CHEM_DEST_RHEL7/perso_results/ || return 100
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo chown -R $USER_SSH_RHEL7:$USER_SSH_RHEL7 $CHEM_DEST_RHEL7 || return 101
            scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $perso_files_path$file3 $perso_files_path$file2 $USER_SSH_RHEL7@$server:$CHEM_DEST_RHEL7 || return 102
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo chmod -R 777 $CHEM_DEST_RHEL7 || return 103
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo bash $CHEM_DEST_RHEL7/$file3 || return 104
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo chown -R $USER_SSH_RHEL7:$USER_SSH_RHEL7 $CHEM_DEST_RHEL7 || return 105
            scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -r $USER_SSH_RHEL7@$server:$CHEM_DEST_RHEL7/perso_results/* ./perso_results/$server/ || return 106
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $USER_SSH_RHEL7@$server sudo rm -rf $CHEM_DEST_RHEL7 || return 107
        else
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes root@$server mkdir -p $CHEM_DEST_RHEL6/perso_results/ || return 108
            scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes $perso_files_path$file1 $perso_files_path$file2 root@$server:$CHEM_DEST_RHEL6 || return 109
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes root@$server "chmod -R 777 $CHEM_DEST_RHEL6 ; bash $CHEM_DEST_RHEL6/$file1" || return 110
            scp -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -r root@$server:$CHEM_DEST_RHEL6/perso_results/* ./perso_results/$server/ || return 111
            ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes root@$server rm -rf $CHEM_DEST_RHEL6 || return 112
    fi
}


function function_run_ssh_command {

    server=$1
    ssh_command_only_for_ssh_errors="echo ''"
    
    if [[ $ostype == "rhel6" ]]
        then
            ssh_run_command_only_for_ssh_errors="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -t root@$server $ssh_command_only_for_ssh_errors"
            ssh_run_command="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -t root@$server bash -c \"$ssh_command\""
        else
            ssh_run_command_only_for_ssh_errors="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -t $USER_SSH_RHEL7@$server sudo $ssh_command_only_for_ssh_errors"
            ssh_run_command="ssh -o ConnectTimeout=2 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o BatchMode=yes -t $USER_SSH_RHEL7@$server sudo bash -c \"$ssh_command\""
    fi  
    
    ssh_run_command_only_for_ssh_errors_result=$($ssh_run_command_only_for_ssh_errors 2>&1)
    ssh_run_command_only_for_ssh_errors_return_code=$? 
    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ssh_run_command_only_for_ssh_errors_return_code = $ssh_run_command_only_for_ssh_errors_return_code"
    
    if [[ $ssh_run_command_only_for_ssh_errors_return_code == "0" ]]  # S'il y a une erreur dès la connexion pour voir les erreur, c'est que la connexion ne marchera pas donc ça ne sert à rien de lancer la cmde ssh ensuite
        then
            if [[ $display_ssh_messages == "0" ]]  # Si on ne veut pas afficher les infos de connexion SSH
                then
                    [[ $log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_result without error display"
                    ssh_run_command_result_without_ssh_messages_display=$($ssh_run_command 2> /dev/null)
                    run_ssh_command_return_code=$? 
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ssh_run_command_result_without_ssh_messages_display : \n\n$ssh_run_command_result_without_ssh_messages_display\n" || echo -e "\n\n$ssh_run_command_result_without_ssh_messages_display\n"  
                    ssh_run_command_result=$ssh_run_command_result_without_ssh_messages_display                
                else
                    [[ $log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_remote_script_result with error display"
                    ssh_run_command_result_with_ssh_messages_display=$($ssh_run_command 2>&1)
                    run_ssh_command_return_code=$? 
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ssh_run_command_result_with_ssh_messages_display : \n\n$ssh_run_command_result_with_ssh_messages_display\n" || echo -e "\n\n$ssh_run_command_result_with_ssh_messages_display\n"
                    ssh_run_command_result=$ssh_run_command_result_with_ssh_messages_display
            fi    
            
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : run_ssh_command_return_code = $run_ssh_command_return_code"
            
            run_ssh_command_status='The return code is not known'
            run_ssh_command_status_details='The return code is not known'
            [[ $run_ssh_command_return_code -eq 1 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='ssh command or ssh connexion KO'
            [[ $run_ssh_command_return_code -eq 254 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='ssh connexion KO'
            [[ $run_ssh_command_return_code -eq 127 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='ssh command not found'
            [[ $run_ssh_command_return_code -eq 0 ]] && run_ssh_command_status="OK" && run_ssh_command_status_details='ssh command OK'
            [[ $run_ssh_command_return_code -eq 6 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='No IP configured ?'
            [[ $run_ssh_command_return_code -eq 2 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='No such file or directory ?'
            [[ $run_ssh_command_return_code -eq 61 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='BSA directory KO'
            [[ $run_ssh_command_return_code -eq 62 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='BSA Process KO'
            [[ $run_ssh_command_return_code -eq 71 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='Route repeater KO'
            [[ $run_ssh_command_return_code -eq 72 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='Route proxysocks KO'
            [[ $run_ssh_command_return_code -eq 80 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='chkconfig KO'
            [[ $run_ssh_command_return_code -eq 81 ]] && run_ssh_command_status="OK" && run_ssh_command_status_details='chkconfig OK'
            [[ $run_ssh_command_return_code -eq 32 ]] && run_ssh_command_status="KO" && run_ssh_command_status_details='Mount KO'
            [[ $run_ssh_command_return_code -eq 50 ]] && run_ssh_command_status="OK" && run_ssh_command_status_details='Pas de fichier cron'
            [[ $run_ssh_command_return_code -eq 77 ]] && run_ssh_command_status="OK" && run_ssh_command_status_details='Pas de montages (autres que srce)'  
            
            if [ "$run_ssh_command_status" == "KO" ] || [ "$run_ssh_command_status" == "The return code is not known" ]
                then
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${RED}$run_ssh_command_status -> $run_ssh_command_status_details${END}"
                    run_ssh_command_status_details="$run_ssh_command_status_details"
                else
                    [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ${GREEN}$run_ssh_command_status -> $run_ssh_command_status_details${END}"
                    run_ssh_command_status_details="$run_ssh_command_status_details"
            fi   
        else
            run_ssh_command_status="KO"
            run_ssh_command_status_details='ssh error' 
            [[ $display_log_full -eq 1 ]] && echo -e "${FUNCNAME[0]} : ssh_run_command_only_for_ssh_errors_result : \n\n$ssh_run_command_only_for_ssh_errors_result\n" || echo -e "\n\n$ssh_run_command_only_for_ssh_errors_result\n"
    fi
}


function function_choose_remote_script_filename {

    echo -e "\n${CYAN}Scripts available (You are free to add new scripts to \"$remote_script_path\" directory) :${END}\n" 
    ls $remote_script_path | nl -s ": "
    echo
    if [ -z "$remote_script_filename_number_choice_arg" ]
        then
            read -e -p "remote_script_filename number ? : " remote_script_filename_number_choice
        else
            read -e -p "remote_script_filename number ? : " remote_script_filename_number_choice <<< $remote_script_filename_number_choice_arg
    fi 
    echo -e "\nOption chosen above : $remote_script_filename_number_choice\n"
    remote_script_filename=$(ls $remote_script_path | nl -s ": " | grep -e " $remote_script_filename_number_choice:" | awk '{print $2}')
    remote_script_path_and_filename=$remote_script_path$remote_script_filename
}


function function_choose_ssh_commands_list_filename {

    echo -e "\n${CYAN}Commands available (You are free to type your own commands or add commands to \"ssh_commands_list_filename\" file) :${END}\n" 
    cat $ssh_commands_list_filename
    echo
    if [ -z "$ssh_command_arg" ]
        then
            read -e -p "ssh_command ? : " ssh_command
        else
            read -e -p "ssh_command ? : " ssh_command <<< $ssh_command_arg
    fi 
    #echo $ssh_command_arg | od -c	
    echo -e "\nCommand which will be executed : $ssh_command\n"
}


function function_choose_servers_exceptions_list_filename {

    echo -e "\n${CYAN}Servers exceptions lists files available (You are free to add your own lists files in \"$servers_exceptions_lists_path\" directory) :${END}\n"
    ls $servers_exceptions_lists_path | nl -s ": "
    echo
    if [ -z "$servers_exceptions_list_filename_number_choice_arg" ]
        then
            read -e -p "servers_exceptions_list_filename number ? : " servers_exceptions_list_filename_number_choice
        else
            read -e -p "servers_exceptions_list_filename number ? : " servers_exceptions_list_filename_number_choice <<< $servers_exceptions_list_filename_number_choice_arg
    fi 
    echo -e "\nOption chosen above : $servers_exceptions_list_filename_number_choice\n"
    servers_exceptions_list_filename=$(ls $servers_exceptions_lists_path | nl -s ": " | grep -e " $servers_exceptions_list_filename_number_choice:" | awk '{print $2}')
    servers_exceptions_list_path_and_filename=$servers_exceptions_lists_path$servers_exceptions_list_filename
}


function function_choose_servers_list_filename {

    echo -e "\n${CYAN}Servers lists files available (You are free to add your own lists files in \"$servers_lists_path\" directory) :${END}\n"
    ls $servers_lists_path | nl -s ": "
    echo
    if [ -z "$servers_list_filename_number_choice_arg" ]
        then
            read -e -p "servers_list_filename number ? : " servers_list_filename_number_choice
        else
            read -e -p "servers_list_filename number ? : " servers_list_filename_number_choice <<< $servers_list_filename_number_choice_arg   
    fi 
    echo -e "\nOption chosen above : $servers_list_filename_number_choice\n"
    servers_list_filename=$(ls $servers_lists_path | nl -s ": " | grep -e " $servers_list_filename_number_choice:" | awk '{print $2}')
    servers_list_path_and_filename=$servers_lists_path$servers_list_filename
}

### MAIN ###

# Creation des repertoires s'il n'existent pas
if [ ! -d "$results_csv_path" ];then mkdir $results_csv_path; fi
if [ ! -d "$remote_script_path" ];then mkdir $remote_script_path; fi
if [ ! -d "$servers_exceptions_lists_path" ];then mkdir $servers_exceptions_lists_path; fi
if [ ! -d "$servers_lists_path" ];then mkdir $servers_lists_path; fi
if [ ! -d "$remote_zip_path" ];then mkdir $remote_zip_path; fi


### MENU ###

echo -e "\n1. function_loop (generates csv result file)"
echo -e "2. function_run_ssh_command"
echo -e "3. function_run_remote_script"
echo -e "4. function_transfer_remote_zip_and_run_ssh_command (${RED}Only for RHEL6${END})"
echo -e "5. function_run_perso_script"
echo -e "q. Exit\n"

if [ -z "$menu1_arg" ]
    then
        read -e -p "Enter your choice: " menu1 #<<< "0"
    else
        read -e -p "Enter your choice: " menu1  <<< $menu1_arg   
fi

echo -e "Option chosen above : $menu1\n"

case $menu1 in
    1)         
        echo -e "\n1. function_run_ssh_command"
        echo -e "2. function_run_remote_script"
        echo -e "3. function_transfer_remote_zip_and_run_ssh_command (${RED}Only for RHEL6${END})"
        echo -e "4. function_run_perso_script"
        echo -e "q. Exit\n"
        
        if [ -z "$menu2_arg" ]
            then
                read -e -p "Choose a function above to run on all servers ? : " menu2 # <<< "0" 
            else
                read -e -p "Choose a function above to run on all servers ? : " menu2 <<< $menu2_arg   
        fi 

        echo -e "Option chosen above : $menu2\n"

        case $menu2 in                
            1)
                function_x="function_run_ssh_command"
                function_loop $function_x
                ;;
                
            2)      
                echo -e "${YELLOW}Attention ! Ne pas oublier d'ajouter à la fin du remote script la ligne pour nettoyer -> rm -f \$0  # Nettoyage${END}\n"
                function_x="function_run_remote_script"                 
                function_loop $function_x
                ;;
                
            3)
                function_x="function_transfer_remote_zip_and_run_ssh_command"
                function_loop $function_x
                ;;  

            4)
                function_x="function_run_perso_script"
                function_loop $function_x
                ;;                
                
            q)
                echo -e "\nBye!"
                exit 0
                ;;
                
            *)
                echo -e "\n${RED}Error: Invalid option chosen...${END}\n"
                ;;
        esac           
        ;;
        
    2)
        function_choose_ssh_commands_list_filename
        echo
        read -e  -p "Server ? : " server
        echo
        function_check_nc $server
        function_run_ssh_command $server
        ;;
        
    3)
        echo -e "${YELLOW}Attention ! Ne pas oublier d'ajouter à la fin du remote script la ligne pour nettoyer -> rm -f \$0  # Nettoyage${END}"
        function_choose_remote_script_filename
        echo
        read -e -p "Server ? : " server
        echo
        function_check_nslookup $server
        function_check_nc $server
        function_run_remote_script $server
        ;; 

    4)
        function_choose_remote_zip_filename
        function_choose_ssh_commands_list_filename
        echo
        read -e -p "Server ? : " server
        echo
        function_check_nc $server
        function_transfer_remote_zip $server
        function_run_ssh_command $server
        ;;        
        
    5)
        read -e -p "Server ? : " server
        echo
        function_check_nslookup $server
        function_check_nc $server
        function_run_perso_script $server  
        run_perso_script_return_code=$?
        [[ $display_log_full -eq 1 ]] && echo -e "\nFunction_run_perso_script : Return code = $run_perso_script_return_code"        
        ;;
        
    q)
        echo -e "\nBye!"
        exit 0
        ;;
        
    *)
        echo -e "\n${RED}Error: Invalid option chosen...${END}\n"
        ;;
esac

