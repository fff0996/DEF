# scGPT 파이프라인 시험 데이터 출처

작성: 2026-11-09. 시험에 쓴 데이터, 논문, 부록 파일, 아틀라스, 변환 도구를 모은다. 서지 정보 중 "확인"은 이 작업 중 원문·공식 페이지에서 본 것이고, "확인 안 함"은 README나 기억에 기댄 것이라 인용 전에 원문을 확인한다.

## 1. 심장: K-BDS KAP241712 (정상 대 심근병증, DCM 대 HCM)

| 항목 | 내용 | 상태 |
|---|---|---|
| K-BDS 과제 | KAP241712 "Characterization of cardiac fibrosis and identification of potential therapeutic targets through a large-scale single-cell atlas" (대규모 단일 세포 아틀라스를 통한 심장 섬유화 특성 규명 및 잠재적 치료 표적 발굴), 숭실대학교, 등록 2025-09-30, 공개 2025-10-23, NTIS 2710069304 | 확인 (공개 페이지) |
| K-BDS 데이터 | GeNA 기타 데이터 507건(예: KGD10058203). 모든 건에 같은 파일 `Heart_atlas_scRNA_seq.tsv.gz`(5,454,887,148 bytes)와 `read_me.txt` | 확인 |
| K-BDS BioSample | 507건(예: KAS24162880, 샘플명 `LV_1290_1_dcm`). 항목: 샘플명, 나이, 수집 일자, 성별, 조직. 질환 항목 없음. 모은 표: `/workspaces/.closha_build_test/scgpt/kap241712_biosamples.csv` | 확인 |
| 행렬 | 세포 2,396,628 × 유전자 16,152, 정수 원본 카운트, 미토콘드리아 유전자 제거, MT 15% 이상·doublet(scrublet) 세포 제거(README) | 확인 |
| 아틀라스 구성(README) | Chaffin 2022 (SCP1303), Kanemaru 2023 (Heart Cell Atlas), Reichart 2022 (CELLxGENE e75342a8-0f3b-4ec5-8ee1-245a23e0f7cb), Kuppe 2022 (CELLxGENE 8191c283-0816-424b-9b61-c3e1d6258a77), Selewa 2023 (GSE224997), Liu 2023 (Figshare 10.6084/m9.figshare.c.5777948.v2), Rao 2021 (GSE145154), Simonson 2023 (SCP1849) | README 그대로 |
| 사용한 부분 | Chaffin 2022 좌심실 샘플 79개, 공여자 42명(정상 16, DCM 11, HCM 15), 세포 578,935개 | 확인 |

### 원출처와 연결 메타데이터
- 논문: Chaffin M, et al. Single-nucleus profiling of human dilated and hypertrophic cardiomyopathy. *Nature* 2022;608:174-180. doi:10.1038/s41586-022-04817-8 (확인: Nature 페이지, 권호·쪽은 확인 안 함)
- 아틀라스: Broad Single Cell Portal SCP1303 "Single-nuclei profiling of human dilated and hypertrophic cardiomyopathy" https://singlecell.broadinstitute.org/single_cell/study/SCP1303 (확인)
- 사용 파일: `DCM_HCM_MetaData_V1.txt`(186,648,760 bytes, 세포 592,689개). 열 `NAME`, `biosample_id`, `donor_id`, `disease__ontology_label`. 다운로드는 포털 로그인 필요.
- 연결 방법: K-BDS 세포 이름에서 `sample<n>` 꼬리를 떼면 SCP1303의 `NAME`(바코드-1-샘플 번호)과 같다. K-BDS 쪽 세포 578,935개가 연결됨.

### 변환 도구
- `tools/scgpt/kbds_heart_to_samples.py`: K-BDS 행렬 + SCP1303 메타데이터 → 샘플별 10x 폴더, `samples.csv`
- DCM 대 HCM 시트: SCP1303 메타데이터의 `biosample_id`-질환 표로 `samples.csv`에서 정상을 빼고 라벨을 DCM/HCM으로 바꿈(awk, 대화 기록).

## 2. 폐암: K-BDS KAP241028 (면역항암제 반응 PR 대 PD)

| 항목 | 내용 | 상태 |
|---|---|---|
| K-BDS 과제 | KAP241028 "Increased inflammatory signature in myeloid cells of non-small cell lung cancer patients with high clonal hematopoiesis", 서울대학교, 등록 2024-11-28, NTIS 2710015194, 기타 데이터 126건 | 확인 |
| 데이터 | 샘플별 `<SampleID>.h5`(Cell Ranger)와 `<SampleID>_metadata.txt.gz`(세포별: cellID, ID, time, Pathology, Response, Clusters, VAF_bin, UMAP). 환자 63명 × Before/After | 확인 (사용자 서버) |
| 라벨 출처 | eLife 논문 Supplementary file 1a "Clinical information of NSCLC cohort with ICI treatment" (`elife-96951-supp1-v2.xlsx`), 열 `ID`, `response_to_ICI`, `scRNA-seq`. scRNA-seq=True 63명: PR 26, PD 37. 조직형 LUAD 29, LUSC 27, Other 7, 성별 남 59, 여 4 | 확인 (https://cdn.elifesciences.org/articles/96951/elife-96951-supp1-v2.xlsx) |
| 논문 | eLife 96951 (Sim et al. 2024로 설계 문서에 기록). 저자·제목은 확인 안 함 | 일부 확인 |

## 3. 루푸스: CELLxGENE (SLE 대 정상)

| 항목 | 내용 | 상태 |
|---|---|---|
| 논문 | Perez RK, et al. Single-cell RNA-seq reveals cell type-specific molecular and genetic associations to lupus. *Science* 2022. doi:10.1126/science.abf1970 | 확인 (CELLxGENE, 검색) |
| GEO | GSE174188: 파일 없음. 원자료는 dbGaP 통제 접근 | 확인 |
| CELLxGENE | 컬렉션 436154da-bcf1-4130-9c8b-120ff9a888f2, 데이터셋 218acb0f-9f2f-4f76-b90b-15a4b7c7f629 "multiplexed scRNA-seq of 1.2 million PBMCs from adult lupus samples", h5ad https://datasets.cellxgene.cziscience.com/c55dc602-d168-4d15-acc1-5de4f2f5d551.h5ad (12,218,105,530 bytes) | 확인 |
| 내용 | 세포 1,263,676, 공여자 261(SLE 162, 정상 99), 샘플 274, raw count는 `raw.X`. 처리 배치(`Processing_Cohort`) 1은 정상만, 2는 대부분 SLE | 확인 |
| 변환 | `tools/scgpt/cellxgene_to_samples.py`, 샘플당 1,000세포, 결과 273k 세포 | 확인 |

## 4. 후보로 확인만 한 데이터
- GSE285888 (Kim GD et al., J Immunother Cancer 2025, PMID 40404203): NSCLC 치료 전 PBMC 33명, 라벨 CR 7 / DR 8 / PD 13 / irAE 5, 한 개의 텍스트 행렬과 세포 메타데이터. DR 정의 미확인.
- COMBAT COVID-19 혈액 아틀라스: CELLxGENE 8f126edf-5405-4731-8374-b5ce11f53e82, 공여자 124명.

## 5. 그림과 방법 참고
- scGPT: Cui H, et al. scGPT: toward building a foundation model for single-cell multi-omics using generative AI. *Nat Methods* 2024 (공개 라이선스 없음, 그림 사용 안 함). 체크포인트 whole_human.
- 개념 그림 B: Do M, Lähdesmäki H. Incorporating hierarchical information into multiple instance learning for patient phenotype prediction with single-cell RNA-sequencing data. *Bioinformatics* 2025;41(Suppl 1). doi:10.1093/bioinformatics/btaf241, PMC12261414, CC BY 4.0, Figure 1.
- 사전학습 임베딩 평가: Kedzierska KZ, et al. Zero-shot evaluation reveals limitations of single-cell foundation models. *Genome Biol* 2025. doi:10.1186/s13059-025-03574-x
