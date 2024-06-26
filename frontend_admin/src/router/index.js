import { createRouter, createWebHistory } from "vue-router";
import Dashboard from "../views/Dashboard.vue";
import Tables from "../views/Tables.vue";
import Signup from "../views/Signup.vue";
import Signin from "../views/Signin.vue";
import Workers from "../views/components/WorkersTable.vue";

const routes = [
  {
    path: "/",
    redirect: "/signin",
  },
  {
    path: "/dashboard",
    name: "Dashboard",
    component: Dashboard,
  },
  {
    path: "/tables",
    name: "Tables",
    component: Tables,
  },
  {
    path: "/workers",
    name: "Workers",
    component: Workers,
  },
  {
    path: "/signin",
    name: "Signin",
    component: Signin,
  },
  {
    path: "/signup",
    name: "Signup",
    component: Signup,
  },
];

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes,
  linkActiveClass: "active",
  scrollBehavior() {
    return { top: 0 }; // 항상 최상단으로 스크롤
  }
});

export default router;
