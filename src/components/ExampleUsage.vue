<template>
  <div class="q-pa-md">
    <div class="row q-gutter-md">
      <!-- Font Awesome Icons Example -->
      <q-card class="col-md-5">
        <q-card-section>
          <div class="text-h6">
            <fa-icon icon="star" class="text-orange q-mr-sm" />
            Font Awesome Icons
          </div>
        </q-card-section>

        <q-card-section>
          <div class="q-gutter-sm">
            <q-btn color="primary" icon-left>
              <fa-icon icon="user" />
              <span class="q-ml-sm">User</span>
            </q-btn>
            <q-btn color="secondary" icon-left>
              <fa-icon icon="home" />
              <span class="q-ml-sm">Home</span>
            </q-btn>
            <q-btn color="positive" icon-left>
              <fa-icon icon="check" />
              <span class="q-ml-sm">Success</span>
            </q-btn>
          </div>

          <div class="q-mt-md">
            <fa-icon icon="heart" class="text-red" />
            <fa-icon icon="search" class="text-blue q-mx-sm" />
            <fa-icon icon="gear" class="text-grey" />
          </div>
        </q-card-section>
      </q-card>

      <!-- Firebase/Firestore Example -->
      <q-card class="col-md-5">
        <q-card-section>
          <div class="text-h6">
            <fa-icon icon="check-circle" class="text-positive q-mr-sm" />
            Firebase Integration
          </div>
        </q-card-section>

        <q-card-section>
          <div class="text-body2 q-mb-md">Firebase services are available globally:</div>

          <div class="q-gutter-sm">
            <q-btn color="primary" @click="testFirebaseConnection" :loading="loading">
              <fa-icon icon="plus" />
              <span class="q-ml-sm">Test Firebase</span>
            </q-btn>

            <q-btn color="secondary" @click="addSampleData" :loading="adding">
              <fa-icon icon="save" />
              <span class="q-ml-sm">Add Sample Data</span>
            </q-btn>
          </div>

          <div v-if="connectionStatus" class="q-mt-md">
            <q-banner
              :class="
                connectionStatus.type === 'positive'
                  ? 'bg-positive text-white'
                  : 'bg-negative text-white'
              "
            >
              <fa-icon
                :icon="connectionStatus.type === 'positive' ? 'check-circle' : 'times-circle'"
              />
              <span class="q-ml-sm">{{ connectionStatus.message }}</span>
            </q-banner>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { collection, addDoc, getDocs } from 'firebase/firestore';
import { db } from 'src/boot/firebase';

const loading = ref(false);
const adding = ref(false);
const connectionStatus = ref<{ type: 'positive' | 'negative'; message: string } | null>(null);

const testFirebaseConnection = async () => {
  loading.value = true;
  connectionStatus.value = null;

  try {
    // Try to access a collection (this will test the connection)
    const testCollection = collection(db, 'test');
    await getDocs(testCollection);

    connectionStatus.value = {
      type: 'positive',
      message: 'Firebase connection successful!',
    };
  } catch (error) {
    console.error('Firebase connection error:', error);
    connectionStatus.value = {
      type: 'negative',
      message: 'Firebase connection failed. Please check your configuration.',
    };
  } finally {
    loading.value = false;
  }
};

const addSampleData = async () => {
  adding.value = true;
  connectionStatus.value = null;

  try {
    const docRef = await addDoc(collection(db, 'examples'), {
      message: 'Hello from Quasar + Firebase!',
      timestamp: new Date(),
      source: 'ExampleUsage component',
    });

    connectionStatus.value = {
      type: 'positive',
      message: `Document added with ID: ${docRef.id}`,
    };
  } catch (error) {
    console.error('Error adding document:', error);
    connectionStatus.value = {
      type: 'negative',
      message: 'Failed to add document. Please check your Firebase configuration.',
    };
  } finally {
    adding.value = false;
  }
};
</script>

<style scoped>
.fa-icon {
  font-size: 1.2em;
}
</style>
