pragma solidity ^0.4.21;

// 소유자 관리용 계약
contract Owned {
    // 상태 변수
    address public owner; // 소유자 주소

    // 소유자 변경 시 이벤트
    event TransferOwnership(address oldaddr, address newaddr);

    // 소유자 한정 메서드용 수식자
    modifier onlyOwner() { if (msg.sender != owner) revert("contract의 소유자가 아닙니다."); _; }

    // 생성자
    constructor() public {
        owner = msg.sender; // 처음에 계약을 생성한 주소를 소유자로 한다
    }

    // (1) 소유자 변경
    function transferOwnership(address _new) onlyOwner public {
        address oldaddr = owner;
        owner = _new;
        emit TransferOwnership(oldaddr, owner);
    }
}

// (2) 회원 관리용 계약
contract Members is Owned {
    // (3) 상태 변수 선언
    address public coin; // 토큰(가상 화폐) 주소
    MemberStatus[] public status; // 회원 등급 배열
    mapping(address => History) public tradingHistory; // 회원별 거래 이력

    // (4) 회원 등급용 구조체
    struct MemberStatus {
        string name; // 등급명
        uint256 times; // 최저 거래 회수
        uint256 sum; // 최저 거래 금액
        int8 rate; // 캐시백 비율
    }
    // 거래 이력용 구조체
    struct History {
        uint256 times; // 거래 회수
        uint256 sum; // 거래 금액
        uint256 statusIndex; // 등급 인덱스
    }

    // (5) 토큰 한정 메서드용 수식자
    modifier onlyCoin() { if (msg.sender == coin) _; }

    // (6) 토큰 주소 설정
    function setCoin(address _addr) onlyOwner public {
        coin = _addr;
    }

    // (7) 회원 등급 추가
    function pushStatus(string _name, uint256 _times, uint256 _sum, int8 _rate) onlyOwner public {
        status.push(MemberStatus({
            name: _name,
            times: _times,
            sum: _sum,
            rate: _rate
            }));
    }

    // (8) 회원 등급 내용 변경
    function editStatus(uint256 _index, string _name, uint256 _times, uint256 _sum, int8 _rate) onlyOwner public {
        if (_index < status.length) {
            status[_index].name = _name;
            status[_index].times = _times;
            status[_index].sum = _sum;
            status[_index].rate = _rate;
        }
    }

    // (9) 거래 내역 갱신
    function updateHistory(address _member, uint256 _value) onlyCoin public {
        tradingHistory[_member].times += 1;
        tradingHistory[_member].sum += _value;
        // 새로운 회원 등급 결정(거래마다 실행)
        uint256 index;
        int8 tmprate;
        for (uint i = 0; i < status.length; i++) {
            // 최저 거래 횟수, 최저 거래 금액 충족 시 가장 캐시백 비율이 좋은 등급으로 설정
            if (tradingHistory[_member].times >= status[i].times &&
            tradingHistory[_member].sum >= status[i].sum &&
            tmprate < status[i].rate) {
                index = i;
            }
        }
        tradingHistory[_member].statusIndex = index;
    }

    // (10) 캐시백 비율 획득(회원의 등급에 해당하는 비율 확인)
    function getCashbackRate(address _member) constant public returns (int8 rate) {
        rate = status[tradingHistory[_member].statusIndex].rate;
    }
}

// (11) 회원 관리 기능이 구현된 가상 화폐
contract OreOreCoin6 is Owned{
    // 상태 변수 선언
    string public name; // 토큰 이름
    string public symbol; // 토큰 단위
    uint8 public decimals; // 소수점 이하 자릿수
    uint256 public totalSupply; // 토큰 총량
    mapping (address => uint256) public balanceOf; // 각 주소의 잔고
    mapping (address => int8) public blackList; // 블랙리스트
    mapping (address => Members) public members; // 각 주소의 회원 정보

    // 이벤트 알림
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Blacklisted(address indexed target);
    event DeleteFromBlacklist(address indexed target);
    event RejectedPaymentToBlacklistedAddr(address indexed from, address indexed to, uint256 value);
    event RejectedPaymentFromBlacklistedAddr(address indexed from, address indexed to, uint256 value);
    event Cashback(address indexed from, address indexed to, uint256 value);

    // 생성자
    constructor(uint256 _supply, string _name, string _symbol, uint8 _decimals) public {
        balanceOf[msg.sender] = _supply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _supply;
    }

    // 주소를 블랙리스트에 등록
    function blacklisting(address _addr) onlyOwner public {
        blackList[_addr] = 1;
        emit Blacklisted(_addr);
    }

    // 주소를 블랙리스트에서 해제
    function deleteFromBlacklist(address _addr) onlyOwner public {
        blackList[_addr] = -1;
        emit DeleteFromBlacklist(_addr);
    }

    // 회원 관리 계약 설정
    function setMembers(Members _members) public {
        members[msg.sender] = Members(_members);
    }

    // 송금
    function transfer(address _to, uint256 _value) public {
        // 부정 송금 확인
        if (balanceOf[msg.sender] < _value) revert("not enough token");
        if (balanceOf[_to] + _value < balanceOf[_to]) revert("token overflow");

        // 블랙리스트에 존재하는 계정은 입출금 불가
        if (blackList[msg.sender] > 0) {
            emit RejectedPaymentFromBlacklistedAddr(msg.sender, _to, _value);
        } else if (blackList[_to] > 0) {
            emit RejectedPaymentToBlacklistedAddr(msg.sender, _to, _value);
        } else {
            // (12) 캐시백 금액을 계산(각 대상의 비율을 사용)
            uint256 cashback = 0;
            if(members[_to] > address(0)) {
                cashback = _value / 100 * uint256(members[_to].getCashbackRate(msg.sender));
                members[_to].updateHistory(msg.sender, _value);
            }

            balanceOf[msg.sender] -= (_value - cashback);
            balanceOf[_to] += (_value - cashback);

            emit Transfer(msg.sender, _to, _value);
            emit Cashback(_to, msg.sender, cashback);
        }
    }
}

// (1) 에스크로
contract Escrow is Owned {
    // (2) 상태 변수
    OreOreCoin6 public token; // 토큰
    uint256 public salesVolume; // 판매량
    uint256 public sellingPrice; // 판매 가격
    uint256 public deadline; // 기한
    bool public isOpened; // 에스크로 개시 플래그

    // (3) 이벤트 알림
    event EscrowStart(uint salesVolume, uint sellingPrice, uint deadline, address beneficiary);
    event ConfirmedPayment(address addr, uint amount);

    // (4) 생성자
    constructor(OreOreCoin6 _token, uint256 _salesVolume, uint256 _priceInEther) public {
        token = OreOreCoin6(_token);
        salesVolume = _salesVolume;
        sellingPrice = _priceInEther * 1 ether;
    }

    // (5) 이름 없는 함수(Ether 수령)
    function () payable public {
        // 개시 전 또는 기한이 끝난 경우에는 예외 처리
        if (!isOpened || now >= deadline) revert();

        // 판매 가격 미만인 경우 예외 처리
        uint amount = msg.value;
        if (amount < sellingPrice) revert();

        // 보내는 사람에게 토큰을 전달하고 에스크로 개시 플래그를 false로 설정
        token.transfer(msg.sender, salesVolume);
        isOpened = false;
        emit ConfirmedPayment(msg.sender, amount);
    }

    // (6) 개시(토큰이 예정 수 이상이라면 개시)
    function start(uint256 _durationInMinutes) onlyOwner public {
        if (token == address(0) || salesVolume == 0 || sellingPrice == 0 || deadline != 0) revert();
        if (token.balanceOf(this) >= salesVolume){
            deadline = now + _durationInMinutes * 1 minutes;
            isOpened = true;
            emit EscrowStart(salesVolume, sellingPrice, deadline, owner);
        }
    }

    // (7) 남은 시간 확인용 메서드(분 단위)
    function getRemainingTime() constant public returns(uint min) {
        if(now < deadline) {
            min = (deadline - now) / (1 minutes);
        }
    }

    // (8) 종료
    function close() onlyOwner public {
        // 토큰을 소유자에게 전송
        token.transfer(owner, token.balanceOf(this));
        // 계약을 파기(해당 계약이 보유하고 있는 Ether는 소유자에게 전송
        selfdestruct(owner);
    }
}
