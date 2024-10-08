package org.ssafy.load.api;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.ssafy.load.application.AdminService;
import org.ssafy.load.application.AreaService;
import org.ssafy.load.application.GoodsService;
import org.ssafy.load.application.WorkerService;
import org.ssafy.load.common.dto.Response;
import org.ssafy.load.dto.TotalDayGoods;
import org.ssafy.load.dto.request.AreaSettingRequest;
import org.ssafy.load.dto.request.worker.LoginRequest;
import org.ssafy.load.dto.response.*;
import org.ssafy.load.dto.response.worker.LoginResponse;

import java.util.List;

@RequiredArgsConstructor
@RestController
@RequestMapping("/admin")
public class AdminController {

    private final AdminService adminService;
    private final GoodsService goodsService;
    private final WorkerService workerService;
    private final AreaService areaService;

    @PostMapping("/login")
    public Response<LoginResponse> login(@RequestBody LoginRequest loginRequest) {
        return Response.success(adminService.login(loginRequest));
    }

    @GetMapping("/good-counts")
    public Response<GoodsCountResponse> getGoodsCount() {
        return Response.success(goodsService.getGoodsCount());
    }

    @GetMapping("/day-counts")
    public Response<GoodsTotalResponse> getDayGoodsCount() {
        return Response.success(goodsService.getDayGoodsCount());
    }

    @GetMapping("/goods")
    public Response<List<GoodsOutputResponse>> getGoodsList() {
        return Response.success(goodsService.getGoodsList());
    }

    @GetMapping("/loads")
    public Response<List<GoodsOutputResponse>> getLoadedGoodsList() {
        return Response.success(goodsService.getLoadedGoodsList());
    }

    @GetMapping("/types")
    public Response<List<BoxTypeResponse>> getBoxTypeCount() {
        return Response.success(goodsService.getBoxTypeCount());
    }

    @GetMapping("/workers")
    public Response<List<WorkerResponse>> getWorkerList() {
        return Response.success(workerService.getWorkerList());
    }

    @PutMapping("/settings")
    public Response<Void> setAreaCount(@RequestBody List<AreaSettingRequest> areaSettingRequest) {
        areaService.setAreaCount(areaSettingRequest);
        return Response.success();
    }

    @GetMapping("/racks")
    public Response<List<RackStoreCountResponse>> getRackStoreGoodsCount(){
        return Response.success(goodsService.getRackStoreGoodsCount());
    }

    @GetMapping("/area")
    public Response<List<AreaResponse>> getAreaInfo(){
        return Response.success(areaService.getAreaInfo());
    }
}
