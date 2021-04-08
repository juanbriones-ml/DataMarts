CREATE OR REPLACE TABLE `meli-bi-data.EXPLOTACION.DATAMART_MELICAMPAIGNS`
CLUSTER BY
 SITE_ID, CAMPAIGN_TYPE, CAMPAIGN_ID
AS (
WITH ELEGIBILIDAD AS (
  SELECT C.CAM_CAMPAIGN_ID CAMPAIGN_ID,
    CASE WHEN C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)].TYPE = 'VOLUME' THEN 'volume' 
      ELSE C.CAM_CAMPAIGN_TYPE END CAMPAIGN_TYPE,
    C.CAM_CAMPAIGN_NAME CAMPAIGN_NAME,
    C.CAM_CAMPAIGN_STATUS CAMPAIGN_STATUS,
    C.CAM_CAMPAIGN_START_DTTM CAMPAIGN_START_DATE,
    C.CAM_CAMPAIGN_FINISH_DTTM CAMPAIGN_FINISH_DATE,
    CASE WHEN CUR_CURRENCY_ID = 'USD' THEN CAM_CAMPAIGN_BUDGET_AMOUNT ELSE CAM_CAMPAIGN_BUDGET_AMOUNT / CONV.CCO_TC_VALUE END AS BUDGET_USD,
    CASE WHEN CUR_CURRENCY_ID = 'USD' THEN CAM_CAMPAIGN_BUDGET_AMOUNT * CONV.CCO_TC_VALUE ELSE CAM_CAMPAIGN_BUDGET_AMOUNT END AS BUDGET_LC,
    C.CUR_CURRENCY_ID CURRENCY_ID,
    C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)].CONFIGS[SAFE_OFFSET(0)].DISCOUNT_VOLUME.TYPE AS VOLUME_TYPE,
    C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)].CONFIGS[SAFE_OFFSET(0)].DISCOUNT_VOLUME.NAME VOLUME_NAME,
    C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)].CONFIGS[SAFE_OFFSET(0)].REBATE_MELI_PERCENTAGE MELI_PERCENTAGE,
    C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)].CONFIGS[SAFE_OFFSET(0)].REBATE_SELLER_PERCENTAGE SELLER_PERCENTAGE,
    C.CAM_CAMPAIGN_STRATEGY_TAKE_RATE TAKE_RATE,
    E.SIT_SITE_ID,
    E.ITE_ITEM_ID,
    MIN(CASE WHEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) BETWEEN s.DIS_START_DATE_DTTM AND S.DIS_END_DATE_DTTM THEN 'ACTIVE' ELSE 'ELIGIBLE' END) AS ELIGIBILITY_STATUS,
    MAX(CASE WHEN S.ITE_ITEM_ID IS NOT NULL THEN 1 ELSE 0 END) HAD_REBATE,
    MIN(CASE WHEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) BETWEEN s.DIS_START_DATE_DTTM AND S.DIS_END_DATE_DTTM THEN DIS_REBATE_MELI_AMOUNT END) AS REBATE_PRICE
  FROM `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS_ELEGIBLE_ITEMS` e
  JOIN `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS` c
      on e.CAM_CAMPAIGN_ID = c.CAM_CAMPAIGN_ID
  LEFT JOIN `meli-bi-data.WHOWNER.LK_MKP_SELLER_DISCOUNTS` s
    on s.ITE_ITEM_ID = e.ITE_ITEM_ID
      and s.SIT_SITE_ID = e.SIT_SITE_ID
      and e.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
  LEFT JOIN `meli-bi-data.WHOWNER.LK_CURRENCY_CONVERTION` CONV 
      ON CONV.TIM_DAY = DATE_ADD(cast(C.CAM_CAMPAIGN_CREATED_DTTM as date), interval -1 day)
        AND TRIM(CONV.SIT_SITE_ID) = C.SIT_SITE_ID
        AND TRIM(CONV.CCO_FROM_CURRENCY_ID) = 'DOL'
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
),

TARGETS AS (
  SELECT SIT_SITE_ID SITE_ID, 
    ITE_ITEM_ID ITEM_ID,
    CAM_CAMPAIGN_ID CAMPAIGN_ID,
    MIN(ITE_ITEM_TARGET_PRICE) TARGET_PRICE
  FROM `meli-bi-data.WHOWNER.LK_MKP_KILLER_ITEMS`
  GROUP BY 1,2,3
),

ITEMS AS (
  SELECT I.SIT_SITE_ID SITE_ID,
    ITE_ITEM_ID ITEM_ID,
    ITE_ITEM_CATALOG_PRODUCT_ID PRODUCT_ID,
    CUS_CUST_ID_SEL SELLER_ID,
    D.VERTICAL,
    ITE_ITEM_DOM_DOMAIN_ID DOMAIN_ID,
    C.CAT_CATEG_ID_L1 CAT_ID_L1,
    C.CAT_CATEG_NAME_L1 CAT_NAME_L1,
    C.CAT_CATEG_ID_L2 CAT_ID_L2,
    C.CAT_CATEG_NAME_L2 CAT_NAME_L2,
    C.CAT_CATEG_ID_L3 CAT_ID_L3,
    C.CAT_CATEG_NAME_L3 CAT_NAME_L3,
    ITE_ITEM_TITLE ITEM_TITLE,
    ITE_ITEM_QUANTITY_AVAILABLE STOCK,
    ITE_ITEM_STATUS STATUS,
    ITE_ITEM_THUMBNAIL THUMBNAIL,
    ITE_ITEM_PERMALINK PERMALINK,
    ITE_ITEM_CONDITION CONDITION,
    CASE WHEN ITE_ITEM_SHIPPING_PAYMENT_TYPE_ID = 'free_shipping' THEN TRUE ELSE FALSE END FS_ITEM,
    CASE WHEN I.SIT_SITE_ID = 'MLC' THEN TRUE
        WHEN I.SIT_SITE_ID = 'MLU' AND ITE_ITEM_LISTING_TYPE_ID_NW <> 'free' THEN TRUE
        WHEN I.SIT_SITE_ID = 'MPE' AND ITE_ITEM_LISTING_TYPE_ID_NW = 'gold_special' THEN TRUE
        WHEN I.SIT_SITE_ID = 'MLV' THEN FALSE
        WHEN ITE_ITEM_LISTING_TYPE_ID_NW = 'gold_pro' THEN TRUE 
        ELSE FALSE 
        END PSJ_ITEM,
    CASE WHEN ITE_ITEM_SHIPPING_LOGISTIC_TYPE = 'drop_off' then 'DS'
        WHEN ITE_ITEM_SHIPPING_LOGISTIC_TYPE = 'xd_drop_off' then 'XD'
        WHEN ITE_ITEM_SHIPPING_LOGISTIC_TYPE = 'cross_docking' then 'XD'
        WHEN ITE_ITEM_SHIPPING_LOGISTIC_TYPE = 'fulfillment' then 'FBM'
        ELSE 'Other' end as LOGISTIC_TYPE,
    CASE WHEN ITE_ITEM_SHIPPING_MODE_ID = 'me2' THEN 'ME2'
        WHEN ITE_ITEM_SHIPPING_MODE_ID = 'me1' THEN 'ME1'
        WHEN ITE_ITEM_SHIPPING_MODE_ID = 'custom' THEN 'Custom'
        ELSE 'Other' END SHIPPING_MODE
  FROM `meli-bi-data.WHOWNER.LK_ITE_ITEMS` I
  LEFT JOIN `meli-bi-data.WHOWNER.LK_DOM_DOMAINS` D
    ON I.ITE_ITEM_DOM_DOMAIN_ID = D.DOM_DOMAIN_ID
  LEFT JOIN `meli-bi-data.WHOWNER.AG_LK_CAT_CATEGORIES` C
    ON I.SIT_SITE_ID = C.SIT_SITE_ID
      AND I.CAT_CATEG_ID = C.CAT_CATEG_ID_L7
      AND C.CAT_DELETED_FLG = False
  WHERE IS_TEST = FALSE
    AND I.ITE_ITEM_ID IN (SELECT ITE_ITEM_ID FROM ELEGIBILIDAD)
),

PRICES AS (
  SELECT I.SIT_SITE_ID SITE_ID,
    I.ITE_ITEM_ID ITEM_ID,
    MIN(ITE_ITEM_PRICE_AMOUNT) PRICE,
    MIN(ITE_ITEM_PRICE_REGULAR_AMOUNT) REGULAR_PRICE
  FROM WHOWNER.LK_ITE_ITEM_PRICES I
  WHERE ITE_ITEM_PRICE_API_STATUS = 'ACTIVE'
    AND (TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) BETWEEN ITE_ITEM_PRICE_START_TIME_DTTM AND ITE_ITEM_PRICE_END_TIME_DTTM
      OR ITE_ITEM_PRICE_TYPE = 'standard')
    AND I.ITE_ITEM_ID IN (SELECT ITE_ITEM_ID FROM ELEGIBILIDAD)
    GROUP BY 1,2
),

ASESORES AS (
  SELECT DISTINCT C.CUS_CUST_ID_SEL,
    SIT_SITE_ID,
    MAX(ASESOR) ASESOR,
    MAX(TIPOFOCO) TIPOFOCO
  FROM
  (
    SELECT DISTINCT CUS_CUST_ID_SEL,
      MAX(FECHA_DESDE) FECHA_DESDE_MAX
    FROM `meli-bi-data.WHOWNER.LK_SALES_CARTERA_GESTIONADA`
    WHERE FECHA_HASTA IS NULL
    GROUP BY 1
  ) X
  JOIN WHOWNER.LK_SALES_CARTERA_GESTIONADA C
    ON C.CUS_CUST_ID_SEL = X.CUS_CUST_ID_SEL
      AND FECHA_DESDE_MAX = FECHA_DESDE
  GROUP BY 1,2
),

SELLERS AS (
  SELECT S.CUS_CUST_ID_SEL,
    S.CUS_NICKNAME SELLER_NICKNAME,
    S.SEGMENTO,
    S.SEGMENTO_SELLER_DETAIL INICIATIVA,
    A.ASESOR
  FROM `meli-bi-data.WHOWNER.LK_MKP_SEGMENTO_SELLERS` S
  LEFT JOIN ASESORES A
    ON S.CUS_CUST_ID_SEL = A.CUS_CUST_ID_SEL
),

ORDERS AS (
  SELECT CAM_CAMPAIGN_ID,
    TIM_DAY,
    SITE_ID,
    ITE_ITEM_ID,
    SUM(GMV) GMV_USD,
    SUM(GMV_LC) GMV_LC,
    SUM(SI) SI,
    SUM(INVERSION) INVERSION_USD,
    SUM(INVERSION_LC) INVERSION_LC,
    SUM(REFUND) REFUND_USD,
    SUM(REFUND_LC) REFUND_LC
  FROM (
      SELECT C.CAM_CAMPAIGN_ID,
        DATE(PAY_PAYMENT_DATE) TIM_DAY,
        SITE_ID,
        ITE_ITEM_ID,
        SUM((QUANTITY - ORD_REFUND_ITEMS) *  UNIT_PRICE * USD_RATIO)  GMV,
        SUM((QUANTITY - ORD_REFUND_ITEMS)  * UNIT_PRICE)  GMV_LC,
        SUM(QUANTITY - ORD_REFUND_ITEMS)  SI,
        NULL INVERSION,
        NULL INVERSION_LC,
        NULL REFUND,
        NULL REFUND_LC
      FROM DATAMART.DM_MKP_ORD_ORDER_COUPONS C
      GROUP BY 1,2,3,4
      HAVING SI > 0

      UNION ALL 

      SELECT CAM_CAMPAIGN_ID,
        TIM_DAY,
        SITE_ID,
        ITE_ITEM_ID,
        NULL GMV,
        NULL GMV_LC,
        NULL SI,
        SUM(PAY_COUPON_AMOUNT - PAY_REFOUND_AMOUNT) INVERSION,
        SUM(PAY_COUPON_AMOUNT_LC - PAY_REFOUND_AMOUNT_LC) INVERSION_LC,
        SUM(PAY_REFOUND_AMOUNT) REFUND,
        SUM(PAY_REFOUND_AMOUNT_LC) REFUND_LC
      FROM (
        SELECT CAM_CAMPAIGN_ID,
          DATE(PAY_PAYMENT_DATE) TIM_DAY,
          SITE_ID,
          ITE_ITEM_ID,
          PAY_COUPON_ID,
          AVG( PAY_COUPON_AMOUNT  * USD_RATIO) PAY_COUPON_AMOUNT,
          AVG( PAY_COUPON_AMOUNT) PAY_COUPON_AMOUNT_LC,
          MAX( PAY_REFOUND_AMOUNT  * USD_RATIO) PAY_REFOUND_AMOUNT,
          MAX( PAY_REFOUND_AMOUNT) PAY_REFOUND_AMOUNT_LC
        FROM DATAMART.DM_MKP_ORD_ORDER_COUPONS
        GROUP BY 1,2,3,4,5
        )
      GROUP BY 1,2,3,4
  )
  GROUP BY 1,2,3,4
)

SELECT E.CAMPAIGN_ID,
  E.SIT_SITE_ID SITE_ID,
  CAMPAIGN_TYPE,
  CAMPAIGN_NAME,
  CAMPAIGN_STATUS,
  CAMPAIGN_START_DATE,
  CAMPAIGN_FINISH_DATE,
  BUDGET_LC,
  BUDGET_USD,
  CURRENCY_ID,
  VOLUME_TYPE,
  VOLUME_NAME,
  MELI_PERCENTAGE,
  SELLER_PERCENTAGE,
  TAKE_RATE,
  TIM_DAY,
  VERTICAL,
  DOMAIN_ID,
  CAT_ID_L1,
  CAT_NAME_L1,
  CAT_ID_L2,
  CAT_NAME_L2,
  CAT_ID_L3,
  CAT_NAME_L3,
  PRODUCT_ID,
  E.ITE_ITEM_ID ITEM_ID,
  ITEM_TITLE,
  CUS_CUST_ID_SEL,
  SELLER_NICKNAME,
  SEGMENTO,
  INICIATIVA,
  ASESOR,
  STOCK,
  STATUS,
  THUMBNAIL,
  PERMALINK,
  PRICE,
  REGULAR_PRICE,
  REBATE_PRICE,
  TARGET_PRICE,
  ELIGIBILITY_STATUS,
  CONDITION,
  FS_ITEM,
  PSJ_ITEM,
  LOGISTIC_TYPE,
  SHIPPING_MODE,
  CASE WHEN HAD_REBATE = 1 THEN TRUE ELSE FALSE END HAD_REBATE,
  GMV_USD,
  GMV_LC,
  SI,
  INVERSION_USD,
  INVERSION_LC,
  REFUND_USD,
  REFUND_LC
FROM ELEGIBILIDAD E
LEFT JOIN  ORDERS O
  ON O.CAM_CAMPAIGN_ID = E.CAMPAIGN_ID
    AND O.ITE_ITEM_ID = E.ITE_ITEM_ID
    AND O.SITE_ID = E.SIT_SITE_ID
LEFT JOIN ITEMS I
  ON E.ITE_ITEM_ID = I.ITEM_ID
    AND E.SIT_SITE_ID = I.SITE_ID
LEFT JOIN SELLERS S
  ON I.SELLER_ID = S.CUS_CUST_ID_SEL
LEFT JOIN PRICES P
  ON E.ITE_ITEM_ID = P.ITEM_ID
    AND E.SIT_SITE_ID = P.SITE_ID
LEFT JOIN TARGETS K
  ON E.ITE_ITEM_ID = K.ITEM_ID
    AND E.SIT_SITE_ID = K.SITE_ID
    AND E.CAMPAIGN_ID = K.CAMPAIGN_ID
)
