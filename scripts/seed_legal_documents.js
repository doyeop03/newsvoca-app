#!/usr/bin/env node

// One-time administrator script. It uses the existing Firebase CLI login,
// creates only missing documents, and never overwrites an existing document.
const path = require('path');

const firebaseToolsLib = path.join(
  process.env.APPDATA || '',
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
);
const { Client } = require(path.join(firebaseToolsLib, 'apiv2'));
const auth = require(path.join(firebaseToolsLib, 'auth'));
const { requireAuth } = require(path.join(firebaseToolsLib, 'requireAuth'));

const projectId = 'newswordapp-7a53b';
const databasePath = `/projects/${projectId}/databases/(default)`;
const checkOnly = process.argv.includes('--check-only');
const client = new Client({
  urlPrefix: 'https://firestore.googleapis.com',
  apiVersion: 'v1',
});

const documents = {
  terms: {
    title: '이용약관',
    version: '1.0',
    effective_date: '2026-08-03',
    is_active: true,
    content: `제1조 목적

본 약관은 NEWSVOCA가 제공하는 뉴스 기반 영어 단어 학습 서비스의 이용 조건과 이용자 및 서비스 간 권리·의무를 정하는 것을 목적으로 합니다.

제2조 서비스 내용

서비스는 뉴스 기반 영어 단어, 예문, 퀴즈, 복습 문제, 기사 학습, 학습 현황 및 알림 기능을 제공합니다. 학습 콘텐츠와 기능은 운영상 필요에 따라 추가·변경될 수 있습니다.

제3조 계정과 로그인

이용자는 이메일·비밀번호 또는 Google 계정으로 로그인할 수 있습니다. 이용자는 본인의 계정 정보를 안전하게 관리해야 하며 타인의 계정을 사용해서는 안 됩니다.

제4조 이용자의 의무

이용자는 관계 법령과 본 약관을 준수해야 합니다. 서비스의 정상 운영을 방해하거나 다른 이용자의 정보 또는 권리를 침해하는 행위를 해서는 안 됩니다.

제5조 학습 콘텐츠

서비스가 제공하는 단어, 예문, 퀴즈와 학습 자료는 학습 보조 목적입니다. 기사 원문은 해당 언론사 또는 콘텐츠 제공자의 권리에 따르며, 원문 보기 기능을 통해 외부 사이트로 이동할 수 있습니다.

제6조 서비스 이용과 변경

네트워크, 외부 서비스, 점검 또는 불가피한 사유로 서비스의 전부 또는 일부가 일시적으로 중단될 수 있습니다. 중요한 변경 사항은 앱 또는 서비스 화면을 통해 안내합니다.

제7조 계정 삭제

이용자는 앱의 마이페이지에서 계정을 삭제할 수 있습니다. 계정 삭제가 완료되면 Firebase Authentication 계정과 저장 단어, 퀴즈, 복습 및 기사 학습 기록이 삭제되며 복구할 수 없습니다.

제8조 책임 제한

서비스는 영어 학습을 돕기 위한 도구이며 특정 학습 결과를 보장하지 않습니다. 외부 기사 사이트의 내용과 운영은 해당 제공자가 책임집니다.

제9조 약관 변경

약관이 변경되는 경우 시행일과 변경 내용을 서비스 화면에 게시합니다. 변경된 약관은 표시된 시행일부터 적용됩니다.`,
  },
  privacy: {
    title: '개인정보처리방침',
    version: '1.0',
    effective_date: '2026-08-03',
    is_active: true,
    content: `1. 개인정보 처리 목적

NEWSVOCA는 회원 인증, 사용자별 학습 데이터 구분, 저장 단어 및 맞춤 복습 제공, 학습 현황 표시, 알림 설정과 서비스 안정성 확인을 위해 필요한 정보를 처리합니다.

2. 처리하는 정보

회원 가입 및 로그인 과정에서 이메일, Firebase UID, 로그인 제공자, 이메일 인증 여부를 처리합니다. 이메일 로그인 비밀번호는 Firebase Authentication이 인증 목적으로 처리하며 Firestore에는 저장하지 않습니다. Google 로그인 시 Google 계정에서 제공되는 이메일과, 제공된 경우 표시 이름 및 프로필 사진을 처리합니다.

서비스 이용 과정에서 관심 카테고리, 일일 학습 목표, 알림 설정, 저장·학습 단어, 정답·오답 횟수, 복습 단계와 일정, 퀴즈 점수 및 완료 기록, 기사 학습 단어와 점수 및 완료 기록을 처리합니다.

기기 또는 브라우저에는 온보딩 완료 여부, 임시 학습 설정, 알림 설정 캐시, 최근 학습 완료 날짜, 퀴즈 완료 여부와 안내 팝업 설정이 저장될 수 있습니다.

3. 처리 방법과 보관

계정과 학습 데이터는 Firebase Authentication 및 Cloud Firestore에 저장됩니다. 일부 화면 설정은 기기 또는 브라우저의 로컬 저장소에 저장됩니다. 코드상 별도의 자동 삭제 기간은 없으며 계정 삭제 시 사용자 Firestore 데이터와 Firebase Authentication 계정을 삭제합니다.

4. 외부 서비스 이용

회원 인증과 데이터 저장을 위해 Google Firebase Authentication, Cloud Firestore 및 Google 로그인을 사용합니다. Firebase Analytics SDK가 포함되어 있어 기본 설정에 따른 앱 실행·기기·서비스 이용 정보가 처리될 수 있습니다. NEWSVOCA Flutter 앱에서 사용자 정보 또는 학습 기록을 외부 AI API로 전송하는 기능은 사용하지 않습니다.

사용자가 기사 원문 보기를 선택하면 해당 언론사 사이트로 이동합니다. 이 경우 외부 사이트는 자체 개인정보처리방침에 따라 접속 정보를 처리할 수 있습니다.

5. 이용자의 권리와 계정 삭제

이용자는 앱에서 자신의 관심 분야, 학습 목표와 알림 설정을 변경할 수 있습니다. 마이페이지의 계정 삭제 기능을 통해 계정과 저장 단어, 퀴즈 결과, 복습 결과 및 기사 학습 기록 삭제를 요청할 수 있습니다. 삭제된 정보는 복구할 수 없습니다.

6. 개인정보 보호

사용자별 Firestore 데이터는 Firebase Authentication UID를 기준으로 본인만 읽고 쓸 수 있도록 제한합니다. 공개 학습 콘텐츠와 법적 고지 문서는 누구나 읽을 수 있지만 Flutter 클라이언트에서 수정하거나 삭제할 수 없습니다.

7. 방침 변경

본 방침이 변경되는 경우 버전과 시행일을 서비스 화면에 표시하며, 변경된 내용은 표시된 시행일부터 적용됩니다.`,
  },
  privacy_consent: {
    title: '개인정보 수집·이용 동의',
    version: '1.0',
    effective_date: '2026-08-03',
    is_active: true,
    content: `1. 수집하는 개인정보 항목

필수 항목
- 이메일 주소
- Firebase UID
- 로그인 제공자
- 이메일 인증 여부
- 가입일, 최근 로그인일 및 수정일

서비스 이용 과정에서 생성되는 정보
- 관심 카테고리
- 일일 학습 목표
- 저장한 단어
- 정답·오답 및 복습 기록
- 퀴즈 점수와 완료 기록
- 기사 학습 기록
- 알림 설정

2. 수집 및 이용 목적

- 회원 인증 및 계정 관리
- 사용자별 학습 데이터 구분
- 학습 진도와 결과 저장
- 저장 단어 및 맞춤 복습 제공
- 알림 설정 및 서비스 운영

3. 보유 및 이용 기간

- 회원 탈퇴 시까지
- 회원 탈퇴 시 Firebase Authentication 계정과 Firestore 사용자 데이터를 삭제합니다.
- 관계 법령에 따라 보관할 필요가 있는 경우 해당 기간 보관합니다.

4. 동의 거부 권리

이용자는 개인정보 수집·이용 동의를 거부할 수 있습니다. 다만 위 정보는 회원가입과 학습 서비스 제공에 필요한 필수 정보이므로 동의하지 않으면 회원가입이 제한됩니다.`,
  },
};

function firestoreFields(value) {
  return Object.fromEntries(
    Object.entries(value).map(([key, fieldValue]) => [
      key,
      typeof fieldValue === 'boolean'
        ? { booleanValue: fieldValue }
        : { stringValue: fieldValue },
    ]),
  );
}

async function exists(documentId) {
  const documentPath = `${databasePath}/documents/legal_documents/${documentId}`;
  try {
    await client.get(documentPath);
    return true;
  } catch (error) {
    if (error.status === 404) return false;
    throw error;
  }
}

async function create(documentId, data) {
  const documentName = `${databasePath}/documents/legal_documents/${documentId}`;
  await client.post(`${databasePath}/documents:commit`, {
    writes: [
      {
        update: { name: `projects/${projectId}/databases/(default)/documents/legal_documents/${documentId}`, fields: firestoreFields(data) },
        updateTransforms: [
          { fieldPath: 'updated_at', setToServerValue: 'REQUEST_TIME' },
        ],
        currentDocument: { exists: false },
      },
    ],
  });
  process.stdout.write(`created ${documentName}\n`);
}

async function main() {
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account) {
    throw new Error('Firebase CLI login is required. Run firebase login first.');
  }
  await requireAuth({
    project: projectId,
    projectDir: process.cwd(),
    user: account.user,
    tokens: account.tokens,
  });

  for (const [documentId, data] of Object.entries(documents)) {
    if (await exists(documentId)) {
      process.stdout.write(`kept existing legal_documents/${documentId}\n`);
      continue;
    }
    if (checkOnly) {
      process.stdout.write(`missing legal_documents/${documentId}\n`);
      continue;
    }
    await create(documentId, data);
  }
}

main().catch((error) => {
  process.stderr.write(`legal document seed failed: ${error.message}\n`);
  process.exitCode = 1;
});
