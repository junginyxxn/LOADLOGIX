package org.ssafy.load.application;

import java.time.LocalDate;
import java.util.ArrayList;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.ssafy.load.common.dto.ErrorCode;
import org.ssafy.load.common.exception.CommonException;
import org.ssafy.load.common.type.BoxType;
import org.ssafy.load.dao.*;
import org.ssafy.load.domain.AreaEntity;
import org.ssafy.load.domain.BoxTypeEntity;
import org.ssafy.load.domain.BuildingEntity;
import org.ssafy.load.domain.GoodsEntity;
import org.ssafy.load.domain.LoadTaskEntity;
import org.ssafy.load.domain.WorkerEntity;
import org.ssafy.load.dto.Building;
import org.ssafy.load.dto.Goods;
import org.ssafy.load.dto.Position;
import org.ssafy.load.dto.request.GoodsCreateRequest;
import org.ssafy.load.dto.response.BoxTypeResponse;
import org.ssafy.load.dto.response.DayGoodsCountResponse;
import org.ssafy.load.dto.response.GoodsCreateResponse;
import org.ssafy.load.dto.response.GoodsCountResponse;
import org.ssafy.load.dto.response.GoodsOutputResponse;
import org.ssafy.load.dto.response.GoodsResponse;

import java.util.List;
import java.util.Optional;
import org.ssafy.load.dto.SortedGoods;
import org.ssafy.load.dto.response.RackStoreCountResponse;
import org.ssafy.load.dto.response.SortedGoodsResponse;

@Service
@RequiredArgsConstructor
@Transactional
public class GoodsService {

    private final WorkerRepository workerRepository;
    private final AreaRepository areaRepository;
    private final BuildingRepository buildingRepository;
    private final GoodsRepository goodsRepository;
    private final LoadTaskRepository loadTaskRepository;
    private final BoxTypeRepository boxTypeRepository;

    @Transactional(readOnly = true)
    public GoodsListResponse getOriginGoods(Long workerId) {
        //기사 조회
        Optional<WorkerEntity> workerOptional = workerRepository.findById(workerId);
        WorkerEntity worker = workerOptional.orElseThrow(() -> new CommonException(ErrorCode.USER_NOT_FOUND));

        //구역 조회
        Optional<AreaEntity> areaOptional = Optional.ofNullable(worker.getArea());
        AreaEntity area = areaOptional.orElseThrow(() -> new CommonException(ErrorCode.AREA_NOT_FOUND));

        //가장 최근 적재 조회
        List<Integer> loadTaskList = loadTaskRepository.findAllByWorkerCompletedTask(area.getId());
        if(loadTaskList.isEmpty()) {
            throw new CommonException(ErrorCode.LOAD_TASK_NOT_FOUND);
        }

        //task에 할당된 상품 조회
        List<GoodsEntity> goodsEntityList = goodsRepository.findByLoadTask(loadTaskList.getFirst());
        Map<BuildingEntity, List<GoodsEntity>> buildingGoodsEntityMap = new HashMap<>();

        for(GoodsEntity goodsEntity : goodsEntityList) {
            buildingGoodsEntityMap.computeIfAbsent(goodsEntity.getBuilding(), k -> new ArrayList<>()).add(goodsEntity);
        }

        //응답 생성
        String areaName = area.getAreaName();
        int total = goodsEntityList.size();
        List<BuildingDetailResponse> buildingDetailResponseList = new ArrayList<>();

        for(BuildingEntity buildingEntity : buildingGoodsEntityMap.keySet()) {
            String topAddress = buildingEntity.getSidoName() + " " + buildingEntity.getGugunName();
            String buildingAddress = buildingEntity.getDongName() + " " + buildingEntity.getZibunMain() + "-" + buildingEntity.getZibunSub();
            int totalGoods = buildingGoodsEntityMap.get(buildingEntity).size();
            int totalPercentage = (int)((double)totalGoods / total * 100);
            List<GoodsDetailResponse> goodsDetailResponseList = new ArrayList<>();

            for (GoodsEntity goodsEntity : buildingGoodsEntityMap.get(buildingEntity)) {
                goodsDetailResponseList.add(
                        new GoodsDetailResponse(
                                goodsEntity.getId(),
                                goodsEntity.getBoxType().getType().name(),
                                goodsEntity.getBoxType().getHeight(),
                                goodsEntity.getBoxType().getLength(),
                                goodsEntity.getBoxType().getWidth(),
                                goodsEntity.getWeight(),
                                goodsEntity.getDetailAddress())
                );
            }

            buildingDetailResponseList.add(
                    new BuildingDetailResponse(
                            topAddress,
                            buildingAddress,
                            totalGoods,
                            totalPercentage,
                            goodsDetailResponseList)
            );
        }
        return new GoodsListResponse(areaName, total, buildingDetailResponseList);
    }

    public SortedGoodsResponse getSortedGoods(Long workerId) {
        //기사 조회
        Optional<WorkerEntity> workerEntityOptional = workerRepository.findById(workerId);
        WorkerEntity worker = workerEntityOptional.orElseThrow(() -> new CommonException(ErrorCode.USER_NOT_FOUND));

        //구역 조회
        Optional<AreaEntity> areaOptionalEntity = Optional.ofNullable(worker.getArea());
        AreaEntity area = areaOptionalEntity.orElseThrow(() -> new CommonException(ErrorCode.AREA_NOT_FOUND));

        //가장 최근 적재 조회
        List<Integer> loadTaskList = loadTaskRepository.findAllByWorkerCompletedTask(area.getId());
        if(loadTaskList.isEmpty()) {
            throw new CommonException(ErrorCode.LOAD_TASK_NOT_FOUND);
        }

        List<GoodsEntity> goodsEntities = goodsRepository.findAllByLoadTaskIdOrderByOrderingAsc(loadTaskList.getFirst());
        List<SortedGoods> goods = goodsEntities.stream()
            .map(g -> new SortedGoods(
                g.getId(),
                String.valueOf(g.getBoxType().getType()),
                new Position(g.getX(), g.getY(), g.getZ()),
                g.getWeight(),
                g.getBuilding().getId(),
                g.getBuilding().getDongName() + " " + g.getBuilding().getZibunMain() + "-"
                    + g.getBuilding().getZibunSub(),
                g.getDetailAddress()
            )).toList();
        return new SortedGoodsResponse(goods);
    }

    public void createGoods(GoodsCreateRequest goodsCreateRequest) {
        try {
            GoodsCreateResponse.from(goodsRepository.save(GoodsEntity.of(
                    null,
                    goodsCreateRequest.weight(),
                    goodsCreateRequest.detailAddress(),
                    null, null, null, null,
                    goodsCreateRequest.agentId(),
                    boxTypeRepository.findByType(BoxType.valueOf("L" + goodsCreateRequest.type()))
                            .orElseThrow(() -> new CommonException(ErrorCode.INVALID_DATA)),
                    buildingRepository.findById(goodsCreateRequest.buildingId())
                            .orElseThrow(() -> new CommonException(ErrorCode.INVALID_DATA)),
                    null, null
            )));
        }catch (Exception e){
            throw new CommonException(ErrorCode.INTERNAL_SERVER_ERROR);
        }
    }

    @Transactional(readOnly = true)
    public GoodsCountResponse getGoodsCount() {
        return new GoodsCountResponse(
            goodsRepository.countAllGoodsByCreatedAtIsToday(),
            goodsRepository.countStoredGoodsByCreatedAtIsToday(),
            goodsRepository.countLoadedGoodsByCreatedAtIsToday()
        );
    }

    @Transactional(readOnly = true)
    public List<DayGoodsCountResponse> getDayGoodsCount() {
        List<Object[]> results = goodsRepository.countGoodsByDateForLastSixDays();
        return results.stream()
            .map(result -> new DayGoodsCountResponse(
                LocalDate.parse(result[0].toString()),
                ((Number) result[1]).longValue()
            )).toList();
    }

    @Transactional(readOnly = true)
    public List<GoodsOutputResponse> getGoodsList() {
        List<GoodsEntity> goods = goodsRepository.findAllGoodsByCreatedAtIsToday();
        return goods.stream()
            .map(good -> {
                BuildingEntity building = good.getBuilding();
                AreaEntity area = areaRepository.findById(building.getArea().getId()).get();

                return new GoodsOutputResponse(
                    area.getAreaName(),
                    good.getDetailAddress(),
                    area.getWorker().getId(),
                    good.getWeight(),
                    String.valueOf(good.getBoxType().getType()),
                    good.getCreatedAt());
            }).toList();
    }

    @Transactional(readOnly = true)
    public List<GoodsOutputResponse> getLoadedGoodsList() {
        List<GoodsEntity> goods = goodsRepository.findAllLoadedGoodsByCreatedAtIsToday();
        return goods.stream()
            .map(good -> {
                BuildingEntity building = good.getBuilding();
                AreaEntity area = areaRepository.findById(building.getArea().getId()).get();

                return new GoodsOutputResponse(
                    area.getAreaName(),
                    good.getDetailAddress(),
                    area.getWorker().getId(),
                    good.getWeight(),
                    String.valueOf(good.getBoxType().getType()),
                    good.getCreatedAt());
            }).toList();
    }

    @Transactional(readOnly = true)
    public List<BoxTypeResponse> getBoxTypeCount() {
        List<Object[]> results = goodsRepository.countBoxTypeByCreatedAtIsToday();
        return results.stream()
            .map(result -> {
                BoxTypeEntity boxType = boxTypeRepository.findById(((Number) result[0]).intValue())
                    .get();
                return new BoxTypeResponse(
                    boxType.getId(),
                    String.valueOf(boxType.getType()),
                    boxType.getHeight(),
                    boxType.getLength(),
                    boxType.getWidth(),
                    ((Number) result[1]).longValue());
            }).toList();
    }

    @Transactional(readOnly = true)
    public List<RackStoreCountResponse> getRackStoreGoodsCount() {
        List<RackStoreCountResponse> result = new ArrayList<>();
        long[] cnt = new long[7];

        List<Object[]> goodsList = goodsRepository.countGoodsByBuildingIdAndCreatedAtIsToday();
        for (Object[] obj : goodsList) {
            Integer areaId = buildingRepository.findById(((Number) obj[0]).longValue()).get()
                .getArea().getId();
            if (areaId == 1) {
                cnt[1] += ((Number) obj[1]).longValue();
            } else if (areaId == 2 || areaId == 3) {
                cnt[2] += ((Number) obj[1]).longValue();
            } else if (areaId == 4) {
                cnt[3] += ((Number) obj[1]).longValue();
            } else if (areaId == 5 || areaId == 6) {
                cnt[4] += ((Number) obj[1]).longValue();
            } else if (areaId == 7) {
                cnt[5] += ((Number) obj[1]).longValue();
            } else {
                cnt[6] += ((Number) obj[1]).longValue();
            }
        }

        for (int i = 1; i <= 6; i++) {
            result.add(new RackStoreCountResponse(i, cnt[i]));
        }
        return result;
    }
}