<script setup>
import { ref } from 'vue';
import {
  getLoadedGoods
} from "@/api/dashboard.js";

const formatTimestamp = (timestamp) => {
  const date = new Date(timestamp);
  const formattedDate = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}:${date.getSeconds().toString().padStart(2, '0')}`;
  return formattedDate;
};

const isLoading = ref(false);
const goods = ref([]);
const getLoadedGoodsRequest = async () => {
  isLoading.value = true;
  const { data } = await getLoadedGoods();
  goods.value = data.result;
  for (let i = 0; i < goods.value.length; i++) {
    goods.value[i].created_at = formatTimestamp(goods.value[i].created_at);
  }
  isLoading.value = false;
};

getLoadedGoodsRequest();
</script>
<template>
  <div class="card mb-4">
    <div class="card-header pb-0">
      <h6>실시간 출고</h6>
    </div>
    <div class="card-body px-0 pt-0 pb-2">
      <div v-if="isLoading" class="table-responsive p-0" style="max-height: 400px; overflow-y: auto;">
        <table class="table align-items-center mb-0">
          <!-- 테이블 상단 -->
          <thead>
            <tr>
              <th
                class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                담당 기사
              </th>
              <th
                class="align-middle text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                구역
              </th>
              <th
                class="align-middle text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7 ps-2"
              >
                주소
              </th>
              <th
                class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                무게
              </th>
              <th class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">
                박스 타입
              </th>
              <th class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">
                출고 시각
              </th>
            </tr>
          </thead>
        </table>
        <div style="display: flex; justify-content: center; align-items: center; height: 50vh;">
          <div class="spinner-border text-primary" role="status">
            <span class="sr-only">Loading...</span>
          </div>
        </div>
      </div>
      <div v-else class="table-responsive p-0" style="max-height: 400px; overflow-y: auto;">
        <table class="table align-items-center mb-0">
          <!-- 테이블 상단 -->
          <thead>
            <tr>
              <th
                class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                담당 기사
              </th>
              <th
                class="align-middle text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                구역
              </th>
              <th
                class="align-middle text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7 ps-2"
              >
                주소
              </th>
              <th
                class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7"
              >
                무게
              </th>
              <th class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">
                박스 타입
              </th>
              <th class="text-center text-uppercase text-secondary text-xxs font-weight-bolder opacity-7">
                출고 시각
              </th>
            </tr>
          </thead>
          <!-- 리스트 시작 -->
          <tbody>
            <tr v-for="good in goods" :key="good.worker_id">
              <!-- 담당 기사 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{good.worker_name}}</p>
              </td>
              <!-- 구역 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{good.area_name}}</p>
              </td>
              <!-- 주소 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{ good.address }}</p>
              </td>
              <!-- 무게 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{good.weight}}g</p>
              </td>
              <!-- 박스 타입 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{ good.box_type }}</p>
              </td>
              <!-- 입고 시각 -->
              <td class="align-middle text-center">
                <p class="text-sm font-weight-bold mb-0">{{good.created_at}}</p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
