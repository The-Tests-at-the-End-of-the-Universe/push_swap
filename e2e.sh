#!/bin/bash

# https://developers.redhat.com/blog/2021/04/23/valgrind-memcheck-different-ways-to-lose-your-memory#generating_a_leak_summary
# https://stackoverflow.com/questions/76698927/why-is-valgrind-ignoring-my-error-exitcode-option
# https://www.cyberciti.biz/faq/unix-howto-read-line-by-line-from-file/#google_vignette
# https://stackoverflow.com/questions/918886/how-do-i-split-a-string-on-a-delimiter-in-bash
# https://phoenixnap.com/kb/bash-increment-decrement-variable#:~:text=12%20to%2013.-,Increment%20Bash%20Variable%20with%20%2B%3D%20Operator,assigned%20in%20a%20single%20statement.
# https://www.baeldung.com/linux/bash-variables-division
# https://stackoverflow.com/questions/169511/how-do-i-iterate-over-a-range-of-numbers-defined-by-variables-in-bash

RED="\x1B[31m"
GRN="\x1B[1;32m"
YEL="\x1B[33m"
BLU="\x1B[34m"
MAG="\x1B[35m"
BMAG="\x1B[1;35m"
CYN="\x1B[36m"
BCYN="\x1B[1;36m"
WHT="\x1B[37m"
RESET="\x1B[0m"
LINEP="\033[40G"
FAIL=false
ERROR_FAIL=false
EXIT_FAIL=false
MEMORY_FAIL=false
CHECK_FAIL=false 
LOGS=logs/ps_log

make re -C ../../ 
rm -rf logs
mkdir -p logs

input=cases/input

x=0

echo -e "${BCYN}input${RESET}"
echo -e "input" >> $LOGS
while read -r line; 
do 
	x=$(( $x + 1 ))
	input=$(echo $line | cut -d "," -f 1)
	expected_exc=$(echo $line | cut -d "," -f 2)
	expected_err=$(echo $line | cut -d "," -f 3)

	echo -ne "${YEL}$x ${BLU}| ${BMAG}$input ${BLU}|${RESET}"
	echo -e " $x | $input " >> $LOGS

	echo -e "stderr output " >> $LOGS
	ERROR=$(echo $input | xargs ../../bin/push_swap 2>&1 >>$LOGS)
	echo -e "exitcode output " >> $LOGS
	../../bin/push_swap $input &>>$LOGS
	if [ $? != $expected_exc ] 
	then 
	EXIT_FAIL=true 
	printf "${RED}EXIT FAIL ${RESET}"
	fi
	if [[ $expected_err != $ERROR ]] 
	then 
	ERROR_FAIL=true 
	printf "${RED}ERROR FAIL ${RESET}"
	fi
	echo -e "valgrind output " >> $LOGS
	valgrind --error-exitcode=42 --leak-check=full --errors-for-leak-kinds=all ../../bin/push_swap $input &>> $LOGS
	if [ $? == 42 ] 
	then 
	MEMORY_FAIL=true 
	printf "${RED}MEMORY FAIL ${RESET}" 
	fi

	if [[ $EXIT_FAIL == false && $ERROR_FAIL == false && $MEMORY_FAIL == false ]];
	then 
	printf " ✅"
	else 
	printf " ❌"
	FAIL=true
	fi
	EXIT_FAIL=false
	ERROR_FAIL=false
	MEMORY_FAIL=false
	printf "\n"
done < $input

test (){
t=0
for x in $(seq $1 $2)
do
t=$(( $t + 1 ))
echo -ne "${YEL}$t ${BLU} | ${BMAG}size:$x ${BLU}| ${RESET}"
echo -e "size:$x" >> $LOGS
count=0
for i in $(seq $3 $4) 
do 
args=$(shuf -i $5-$x | tr '\n' ' ')
echo -e "valgrind output" >> $LOGS
valgrind --error-exitcode=42 --leak-check=full --errors-for-leak-kinds=all ../../bin/push_swap $args &>> $LOGS
mem_exitcode=$?
((count+=$(../../bin/push_swap $args | wc -l))) 
echo -e "checker output" >> $LOGS
../../bin/push_swap $args | ./checker_linux $args &>> $LOGS
check_exitcode=$?
done

count=$(expr $count / $4)
if [ $mem_exitcode == 42 ] 
then 
MEMORY_FAIL=true 
echo "mem_exitcode $check_exitcode" >> $LOGS
printf "${RED}MEMORY FAIL ${RESET}" 
fi
if [ $check_exitcode != 0 ] 
then 
CHECK_FAIL=true 
echo "check_exitcode $check_exitcode" >> $LOGS
printf "${RED}CHECK FAIL ${RESET}" 
fi

printf "${BMAG}AVG:${count} ${RESET}" 

if [[ $CHECK_FAIL == false && $MEMORY_FAIL == false ]];
then 
printf " ✅"
else 
printf " ❌"
FAIL=true
fi
CHECK_FAIL=false
MEMORY_FAIL=false
printf "\n"
done 
}

echo -e "${BCYN}small arrays 1-8${RESET}"
echo -e "${BCYN}small arrays 1-8${RESET}" >> $LOGS
test 1 8 1 10 1
echo -e "${BCYN}1-500${RESET}"
echo -e "${BCYN}1-500${RESET}" >> $LOGS
test 1 500 1 1 1

if [ $FAIL = true ];
then 
echo -e "${RED}Check $LOGS ${RESET}"
exit 1
else 
echo -e "${GRE}Congratulations, all tests are succesfull :)${RESET}"
rm -rf $LOGS
fi
