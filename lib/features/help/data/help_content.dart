// 앱 사용 가이드 + 볼링 용어 정적 콘텐츠.
//
// 정적 데이터로 유지하는 이유:
// - 변경 빈도가 낮고 오프라인에서도 보여야 함.
// - 백엔드 추가 인프라 없이 곧장 노출 가능.
//
// 신규 항목 추가 시 이 파일만 수정하면 HelpPage에 자동 반영된다.

class HelpGuideSection {
  const HelpGuideSection({required this.title, required this.items});
  final String title;
  final List<HelpGuideItem> items;
}

class HelpGuideItem {
  const HelpGuideItem({required this.title, required this.body});
  final String title;
  final String body;
}

class BowlingTerm {
  const BowlingTerm({
    required this.term,
    this.symbol,
    this.english,
    required this.description,
  });
  final String term;
  final String? symbol;
  final String? english;
  final String description;
}

const List<HelpGuideSection> kHelpGuideSections = [
  HelpGuideSection(
    title: '게임 기록하기',
    items: [
      HelpGuideItem(
        title: '새 게임 시작',
        body: '홈 화면 또는 클럽 화면에서 "새 게임"을 시작합니다. '
            '게임 모드를 고르고 기록할 게임 종류(단일·시리즈)를 선택하세요.',
      ),
      HelpGuideItem(
        title: '점수 입력',
        body: '하단 키패드의 숫자를 누르면 현재 프레임 1투, 2투에 자동으로 입력됩니다. '
            '스트라이크는 X, 스페어는 / 버튼을 사용하세요. 자동으로 다음 프레임으로 이동합니다.',
      ),
      HelpGuideItem(
        title: '10프레임 특수 규칙',
        body: '10프레임에서 스트라이크나 스페어를 치면 보너스 투구가 주어져 최대 3투까지 가능합니다. '
            '키패드는 이 규칙을 자동 반영합니다.',
      ),
      HelpGuideItem(
        title: '잘못 입력했을 때',
        body: '키패드의 ← 백스페이스로 직전 투구를 취소할 수 있습니다. '
            '프레임 카드를 직접 탭해도 해당 프레임으로 이동합니다.',
      ),
    ],
  ),
  HelpGuideSection(
    title: '시리즈',
    items: [
      HelpGuideItem(
        title: '시리즈란?',
        body: '여러 게임(보통 3 또는 6게임)을 한 단위로 묶어 평균과 합계를 추적하는 단위입니다.',
      ),
      HelpGuideItem(
        title: '시리즈 만들기',
        body: '게임 모드 선택 시 시리즈 옵션을 켜고 목표 게임 수를 선택합니다. '
            '게임을 저장할 때마다 시리즈 진행률이 업데이트됩니다.',
      ),
      HelpGuideItem(
        title: '시리즈 평균 배지',
        body: '시리즈 평균 180/200을 달성하면 배지를 받습니다.',
      ),
    ],
  ),
  HelpGuideSection(
    title: '클럽',
    items: [
      HelpGuideItem(
        title: '다른 클럽 둘러보기',
        body: '내 클럽 화면 하단의 "다른 클럽 둘러보기"에서 모든 클럽의 평균 점수와 멤버 수를 볼 수 있습니다.',
      ),
      HelpGuideItem(
        title: '가입 신청',
        body: '클럽 탐색 페이지에서 카드를 탭해 신청합니다. 클럽 운영자의 승인을 받으면 멤버가 됩니다.',
      ),
      HelpGuideItem(
        title: '실시간 클럽 게임',
        body: '클럽 게임 모드에서 방을 만들고 코드를 공유하면 멤버들이 함께 점수를 입력하고 실시간으로 순위를 볼 수 있습니다.',
      ),
      HelpGuideItem(
        title: '운영자 위임 / 탈퇴',
        body: '운영자는 멤버 관리 페이지에서 다른 멤버에게 운영자를 위임할 수 있습니다. '
            '일반 멤버는 클럽 헤더의 탈퇴 아이콘으로 즉시 탈퇴할 수 있습니다.',
      ),
    ],
  ),
  HelpGuideSection(
    title: '통계와 배지',
    items: [
      HelpGuideItem(
        title: '에버리지 3가지',
        body: '개인 에버리지: 혼자 친 게임만의 평균. 클럽 에버리지: 클럽 게임만의 평균. '
            '종합 에버리지: 모든 게임의 평균. 홈과 멤버 통계 페이지에서 함께 표시됩니다.',
      ),
      HelpGuideItem(
        title: '출석 streak',
        body: '게임을 기록한 날짜가 연속될수록 streak 일수가 늘어납니다. '
            '3·7·30·100일 연속 시 배지를 획득합니다.',
      ),
      HelpGuideItem(
        title: '배지',
        body: '게임 수, 점수, 스트라이크, 시리즈, 클럽 활동 등 다양한 카테고리에서 자동으로 부여됩니다. '
            '게임 저장 직후 새 배지가 있으면 축하 화면이 표시됩니다.',
      ),
    ],
  ),
];

/// 가나다순으로 정렬해 보관. 검색 시 term/english/description 모두 매칭.
const List<BowlingTerm> kBowlingTerms = [
  BowlingTerm(
    term: '스트라이크',
    symbol: 'X',
    english: 'Strike',
    description: '1투에 핀 10개를 모두 쓰러뜨리는 것. 다음 2투의 점수까지 보너스로 가산됩니다.',
  ),
  BowlingTerm(
    term: '스페어',
    symbol: '/',
    english: 'Spare',
    description: '1투에서 남긴 핀을 2투에서 모두 쓰러뜨리는 것. 다음 1투의 점수를 보너스로 가산합니다.',
  ),
  BowlingTerm(
    term: '오픈',
    symbol: '−',
    english: 'Open Frame',
    description: '한 프레임을 스트라이크나 스페어 없이 마치는 것. 보너스 점수가 없습니다.',
  ),
  BowlingTerm(
    term: '프레임',
    english: 'Frame',
    description: '한 게임은 10프레임으로 구성됩니다. 각 프레임에서 최대 2투(10프레임은 최대 3투)를 합니다.',
  ),
  BowlingTerm(
    term: '10프레임 보너스',
    english: 'Bonus Throws',
    description: '10프레임 1투가 스트라이크거나 1·2투 합이 10이면 보너스 투구가 주어져 최대 3투까지 가능합니다.',
  ),
  BowlingTerm(
    term: '더블',
    english: 'Double',
    description: '연속 2번의 스트라이크.',
  ),
  BowlingTerm(
    term: '터키',
    english: 'Turkey',
    description: '연속 3번의 스트라이크.',
  ),
  BowlingTerm(
    term: '퍼펙트 게임',
    english: 'Perfect Game',
    description: '한 게임에서 12번 연속 스트라이크를 쳐 300점을 기록하는 것.',
  ),
  BowlingTerm(
    term: '에버리지',
    english: 'Average',
    description: '평균 점수. 전체·개인·클럽 단위로 따로 볼 수 있습니다.',
  ),
  BowlingTerm(
    term: '올커버',
    english: 'All Cover',
    description: '한 게임의 모든 프레임을 스트라이크 또는 스페어로 채워 오픈 프레임이 0인 게임.',
  ),
  BowlingTerm(
    term: '시리즈',
    english: 'Series',
    description: '여러 게임(보통 3·6게임)을 묶어 합계·평균을 추적하는 단위.',
  ),
  BowlingTerm(
    term: '핀',
    english: 'Pin',
    description: '레인 끝에 세워진 10개의 표적.',
  ),
  BowlingTerm(
    term: '레인',
    english: 'Lane',
    description: '볼링공이 굴러가는 트랙. 길이 약 18.3m.',
  ),
  BowlingTerm(
    term: '거터',
    english: 'Gutter',
    description: '레인 양 옆의 도랑. 공이 빠지면 점수 0.',
  ),
  BowlingTerm(
    term: '파울',
    english: 'Foul',
    description: '투구 시 파울 라인을 넘는 행위. 해당 투구의 점수는 0으로 처리됩니다.',
  ),
  BowlingTerm(
    term: '스플릿',
    english: 'Split',
    description: '1투 후 남은 핀 사이가 떨어져 있어 스페어 처리가 어려운 배치.',
  ),
  BowlingTerm(
    term: '핸디캡',
    english: 'Handicap',
    description: '실력차를 보정하기 위해 평균이 낮은 선수에게 부여하는 가산점.',
  ),
];
