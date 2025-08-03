import { FirebaseApp } from 'firebase/app';
import { Firestore } from 'firebase/firestore';
import { Auth } from 'firebase/auth';

declare module '@vue/runtime-core' {
  interface ComponentCustomProperties {
    $firebase: FirebaseApp;
    $db: Firestore;
    $auth: Auth;
  }
}
