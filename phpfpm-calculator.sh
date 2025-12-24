#!/usr/bin/env bash
################################################################
# php-fpm pool calculater.
#   ex~]# ./phpfpm-calculator.sh 3
#         ./phpfpm-calculator.sh [number of pool]
#
#                     2025-12-24 by Enteroa(enteroa.j@gmail.com)
################################################################

# 설정값들
DEFAULT_CHILD_MEMORY=19087          # 기본 child 메모리 (KB)
MEMORY_BUFFER_PERCENT=10            # 메모리 버퍼 비율 (%)
DEFAULT_MAX_REQUESTS=500            # 기본 max_requests 값
MIN_PROCESSES=5                     # 최소 프로세스 수
MIN_SPARE_SERVERS=1                 # 최소 spare 서버 수
MAX_SPARE_SERVERS=3                 # 최소 max spare 서버 수
START_SERVERS=2                     # 최소 start 서버 수
DEBUG_MODE=false                    # 디버그 모드 (true/false)

# 색상 정의
RED="\e[31;1m"
GREEN="\e[32;1m"
YELLOW="\e[33;1m"
RESET="\e[0m"
TEAR_OFF="${RED}-----------------------------------------${RESET}"

# 입력 검증 함수
validate_input() {
    local input=$1
    if [[ -z "$input" ]]; then
        echo -e "${YELLOW}경고: 풀 개수가 지정되지 않았습니다. 기본값 1을 사용합니다.${RESET}"
        return 0
    fi
    
    if [[ ! "$input" =~ ^[0-9]+$ ]] || [[ "$input" -le 0 ]]; then
        echo -e "${RED}오류: 양의 정수를 입력해주세요. 입력값: $input${RESET}" >&2
        echo "사용법: $0 [풀 개수]"
        exit 1
    fi
    
    if [[ "$input" -gt 100 ]]; then
        echo -e "${YELLOW}경고: 풀 개수가 매우 큽니다 ($input). 계속 진행합니다.${RESET}"
    fi
}

# 디버그 로그 함수
debug_log() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${YELLOW}[DEBUG] $1${RESET}" >&2
    fi
}

# 프로세스 메모리 사용량 계산 함수
calculate_process_memory() {
    local process_name=$1
    local total_memory=0
    local pid_count=0
    
    debug_log "프로세스 '$process_name' 메모리 계산 중..."
    
    # 프로세스 존재 여부 확인
    if ! pgrep -x "$process_name" > /dev/null 2>&1; then
        debug_log "프로세스 '$process_name'를 찾을 수 없습니다."
        echo 0
        return
    fi
    
    for pid in $(pgrep -x "$process_name" 2>/dev/null); do
        if [[ -r "/proc/$pid/smaps" ]]; then
            local pss=$(awk '/Pss:/{x+=$2}END{print x+0}' "/proc/$pid/smaps" 2>/dev/null)
            total_memory=$((total_memory + pss))
            pid_count=$((pid_count + 1))
            debug_log "PID $pid: ${pss}KB"
        else
            debug_log "경고: /proc/$pid/smaps 파일을 읽을 수 없습니다."
        fi
    done
    
    debug_log "프로세스 '$process_name' 총 메모리: ${total_memory}KB (프로세스 수: $pid_count)"
    echo "$total_memory"
}
# 메모리 정보 수집 함수
get_memory_info() {
    debug_log "시스템 메모리 정보 수집 중..."
    
    local meminfo
    if ! meminfo=$(free -k 2>/dev/null | grep "^Mem:"); then
        echo -e "${RED}오류: 메모리 정보를 가져올 수 없습니다.${RESET}" >&2
        exit 1
    fi
    
    RAMTOTAL=$(echo "$meminfo" | awk '{print $2}')
    RAMUSED=$(echo "$meminfo" | awk '{print $3}')
    RAMBUFF=$(echo "$meminfo" | awk '{print $6}')
    RAMFREE=$(echo "$meminfo" | awk '{print $4}')
    
    debug_log "총 메모리: ${RAMTOTAL}KB, 사용중: ${RAMUSED}KB, 버퍼: ${RAMBUFF}KB, 여유: ${RAMFREE}KB"
    
    # 메모리 정보 유효성 검사
    if [[ "$RAMTOTAL" -le 0 ]] || [[ -z "$RAMTOTAL" ]]; then
        echo -e "${RED}오류: 유효하지 않은 메모리 정보입니다.${RESET}" >&2
        exit 1
    fi
}

# 메모리 정보 출력 함수
display_memory_info() {
    echo -e "$TEAR_OFF"
    printf "%-9s %-7s %-7s %-7s %-7s\n" "" "TOTAL" "USED" "BUFF" "FREE"
    echo -e "$TEAR_OFF"
    printf "%-9s %-7s %-7s %-7s %-7s\n" \
        "MEMORY" \
        "$(awk '{printf "%0.0f", $1/1024}' <<< "$RAMTOTAL")M" \
        "$(awk '{printf "%0.0f", $1/1024}' <<< "$RAMUSED")M" \
        "$(awk '{printf "%0.0f", $1/1024}' <<< "$RAMBUFF")M" \
        "$(awk '{printf "%0.0f", $1/1024}' <<< "$RAMFREE")M"
    echo -e "$TEAR_OFF"
}

# 프로세스별 메모리 사용량 출력 함수
display_process_memory() {
    local processes=("nginx" "httpd" "apache2" "mariadbd" "mysqld" "php-fpm")
    PHPMEM=0
    
    for process in "${processes[@]}"; do
        local memory_usage
        memory_usage=$(calculate_process_memory "$process")
        
        if [[ "$memory_usage" -gt 0 ]]; then
            echo "$process used $(awk '{printf "%0.1f", $1/1024}' <<< "$memory_usage")MB"
            if [[ "$process" == "php-fpm" ]]; then
                PHPMEM=$memory_usage
            fi
        fi
    done
    echo -e "$TEAR_OFF"
}

# PHP-FPM child 프로세스 평균 메모리 계산 함수
calculate_phpfpm_child_memory() {
    debug_log "PHP-FPM child 프로세스 메모리 계산 중..."
    
    local child_memory
    child_memory=$(ps --no-headers --sort -size -o size,command axc 2>/dev/null | \
                   awk '/php-fpm/&&!/master process/{x+=$1;l+=1}END{if(l>0) print int(x/l); else print 0}')
    
    if [[ -z "$child_memory" ]] || [[ "$child_memory" -eq 0 ]]; then
        child_memory=$DEFAULT_CHILD_MEMORY
        echo -e "${YELLOW}PHP-FPM 프로세스가 실행중이지 않습니다. 기본값 $(awk '{printf "%0.1f", $1/1024}' <<< "$DEFAULT_CHILD_MEMORY")M을 사용합니다.${RESET}" >&2
    fi
    
    echo "$child_memory"
}

# PHP-FPM 프로세스 정보 출력 함수
display_phpfpm_processes() {
    debug_log "PHP-FPM 프로세스 정보 출력 중..."
    
    # 실행중인 PHP-FPM 프로세스 정보 출력
    local process_info
    process_info=$(ps --no-headers --sort -size -o size,command ax 2>/dev/null | \
                   grep php-fpm | grep -v grep)
    
    if [[ -n "$process_info" ]]; then
        echo "$process_info" | \
        awk '!/grep/{printf("%0.2f MB ", $1/1024)}{for(x=2;x<=NF;x++){printf("%s ", $x)}print ""}'
    fi
}
# 사용 가능한 메모리 계산 함수
calculate_available_memory() {
    local pool_count=$1
    local php_memory=$2
    
    debug_log "사용 가능한 메모리 계산: 풀 개수=$pool_count, PHP 메모리=${php_memory}KB"
    
    local buffer_memory=$((RAMTOTAL * MEMORY_BUFFER_PERCENT / 100))
    local available_memory=$((RAMFREE + RAMBUFF + php_memory - buffer_memory))
    local per_pool_memory=$((available_memory / pool_count))
    
    debug_log "풀당 사용 가능한 메모리: ${per_pool_memory}KB"
    echo "$per_pool_memory"
}

# 메모리 계산 정보 출력 함수
display_memory_calculation() {
    local pool_count=$1
    local php_memory=$2
    local per_pool_memory=$3
    
    local buffer_memory=$((RAMTOTAL * MEMORY_BUFFER_PERCENT / 100))
    local available_memory=$((RAMFREE + RAMBUFF + php_memory - buffer_memory))
    
    echo -n "FreeMemory($(awk '{printf "%0.1f", $1/1024/1024}' <<< "$RAMFREE")G) + "
    echo -n "Buffer($(awk '{printf "%0.1f", $1/1024/1024}' <<< "$RAMBUFF")G) + "
    echo -n "PHP_Consume($(awk '{printf "%0.1f", $1/1024/1024}' <<< "$php_memory")G) - "
    echo -n "Memory_${MEMORY_BUFFER_PERCENT}%($(awk '{printf "%0.1f", $1/1024/1024}' <<< "$buffer_memory")G) = "
    echo "$(awk '{printf "%0.1f", $1/1024/1024}' <<< "$available_memory")G"
}

# PHP-FPM 설정 생성 함수
generate_phpfpm_config() {
    local per_pool_memory=$1
    local child_memory=$2
    local pool_count=$3
    
    debug_log "PHP-FPM 설정 생성: 풀당 메모리=${per_pool_memory}KB, child 메모리=${child_memory}KB"
    
    local per_memory_mb=$((per_pool_memory / 1024))
    local child_memory_mb=$((child_memory / 1024))
    
    # 기본 계산
    local max_children=$((per_memory_mb / child_memory_mb))
    local min_spare=$((max_children * 25 / 100))
    local max_spare=$((max_children * 75 / 100))
    local start_servers=$(((min_spare + max_spare) / 2))
    
    # 최소값 보장
    [[ $min_spare -lt $MIN_SPARE_SERVERS ]] && min_spare=$MIN_SPARE_SERVERS
    [[ $max_spare -lt $MAX_SPARE_SERVERS ]] && max_spare=$MAX_SPARE_SERVERS
    [[ $start_servers -lt $START_SERVERS ]] && start_servers=$START_SERVERS
    [[ $max_children -lt $MIN_PROCESSES ]] && max_children=$MIN_PROCESSES
    
    # 논리적 검증
    if [[ $min_spare -ge $max_spare ]]; then
        max_spare=$((min_spare + 2))
    fi
    if [[ $start_servers -lt $min_spare ]] || [[ $start_servers -gt $max_spare ]]; then
        start_servers=$(((min_spare + max_spare) / 2))
    fi
    
    debug_log "계산된 설정값: max_children=$max_children, start_servers=$start_servers, min_spare=$min_spare, max_spare=$max_spare"
    
    echo "$pool_count site use to $(awk '{printf "%0.1f", $1/1024}' <<< "$per_pool_memory")M memory per each."
    echo -e "$TEAR_OFF"
    echo -e "pm                              = dynamic"
    echo -e "pm.max_children                 = $max_children"
    echo -e "pm.start_servers                = $start_servers"
    echo -e "pm.min_spare_servers            = $min_spare"
    echo -e "pm.max_spare_servers            = $max_spare"
    echo -e "pm.max_requests                 = $DEFAULT_MAX_REQUESTS"
}

# 메인 실행 함수
main() {
    # 입력 검증
    validate_input "$1"
    
    # 풀 개수 설정
    local pool_count=${1:-1}
    
    debug_log "스크립트 시작: 풀 개수=$pool_count"
    
    # 메모리 정보 수집
    get_memory_info
    
    # 메모리 정보 출력
    display_memory_info
    
    # 프로세스별 메모리 사용량 출력
    display_process_memory
    
    # PHP-FPM child 메모리 계산
    local child_memory
    child_memory=$(calculate_phpfpm_child_memory)
    
    # PHP-FPM 프로세스 정보 출력
    display_phpfpm_processes
    echo -e "${GREEN}php-fpm child average memory usage $(awk '{printf "%0.1f", $1/1024}' <<< "$child_memory")M${RESET}"
    echo -e "$TEAR_OFF"
    
    # 사용 가능한 메모리 계산
    local per_pool_memory
    per_pool_memory=$(calculate_available_memory "$pool_count" "$PHPMEM")
    
    # 메모리 계산 정보 출력
    display_memory_calculation "$pool_count" "$PHPMEM" "$per_pool_memory"
    echo -e "$TEAR_OFF"
    
    # PHP-FPM 설정 생성
    generate_phpfpm_config "$per_pool_memory" "$child_memory" "$pool_count"
    echo -e "$TEAR_OFF"
    
    debug_log "스크립트 완료"
}

# 스크립트 실행
main "$@"
