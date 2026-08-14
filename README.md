# wordapp

## 로그인 세션 유지

앱은 Firebase Auth의 `currentUser`와 `authStateChanges()`를 기준으로 로그인
상태를 판단합니다. 일반적인 앱 종료나 재실행, hot restart만으로는 사용자를
로그아웃하지 않습니다. Web에서는 Firebase 초기화 직후 `Persistence.LOCAL`을
설정합니다.

다음 상황에서는 개발 또는 플랫폼 환경에 저장된 인증 세션이 사라질 수 있습니다.

- 앱 삭제 후 재설치
- `flutter clean` 과정에서 플랫폼 앱 데이터까지 초기화한 경우
- 브라우저 사이트 데이터 삭제
- 시크릿 모드 사용
- Firebase 프로젝트 또는 `google-services.json` 변경
- 다른 Firebase 앱 설정으로 교체

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
