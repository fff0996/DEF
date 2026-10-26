# 포탈 등록용 이미지 (2026-10-23 배포)

포탈에 그대로 올리는 PNG만 모았습니다. 모듈 폴더마다 분석 개념 그림(`<모듈>_concept.png`)과 주요 결과 그림(`<모듈>_result_<N>.png`)이 있고, 번호는 원고(`docs/Portal_Content.docx`)의 "결과 N"과 같습니다.

- 분석 개념 그림 1(`<모듈>_concept.png`)은 지금 동작에 맞춰 직접 그린 그림이고, train의 그림 2(`rtpred_train_concept_2.png`)는 원리를 설명하는 CC BY 논문 그림을 포탈 스타일로 다시 그린 것입니다(출처는 원고). 결과 그림은 서울대가 준 예제 실행 결과(`docs/RTpred/images/`)를 이름만 바꿔 복사했습니다.
- `pipeline/`: 파이프라인 페이지의 분석 흐름(`pipeline.png`), 분석 개념(`concept.png`: Xie 외 2025 Fig. 1 원본, CC BY 4.0), 대표 이미지(`thumbnail.png`: RepoRT 공개 실측 자료로 돌린 rtpred_compare 산점도, HILIC)
- CLOSHA에서 실측 데이터로 실행한 뒤 결과 그림을 바꾸려면 `results/<모듈>/`에 올리고 다음 배포에서 교체합니다.
