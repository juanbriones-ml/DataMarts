CREATE OR REPLACE TABLE `meli-bi-data.EXPLOTACION.TBL_MELICAMPAIGNS_UPLIFT` AS (
WITH PRODUCTS_DIARIOS AS (
  SELECT DIS_CAMPAIGN_ID, 
    SIT_SITE_ID,
    PRD_PRODUCT_ID,
    DIA,
    DATE_SUB(DIA, INTERVAL 28 DAY) DIA_28
  FROM (SELECT DIS_CAMPAIGN_ID,
      s.SIT_SITE_ID,
      PRD_PRODUCT_ID,
      DIS_DISCOUNT_ID,
      DIA,
      SUM(CASE WHEN DATE(s.DIS_START_DATE_DTTM) <> DIA AND DATE(s.DIS_END_DATE_DTTM) <> DIA THEN 24
        WHEN DATE(s.DIS_START_DATE_DTTM) = DIA AND DATE(s.DIS_END_DATE_DTTM) = DIA THEN TIMESTAMP_DIFF(S.DIS_END_DATE_DTTM, s.DIS_START_DATE_DTTM, MINUTE) / 60
        WHEN DATE(s.DIS_START_DATE_DTTM) = DIA THEN TIME_DIFF(TIME(23,59,59), TIME(s.DIS_START_DATE_DTTM), MINUTE) / 60
        WHEN DATE(s.DIS_END_DATE_DTTM) = DIA THEN TIME_DIFF(TIME(s.DIS_END_DATE_DTTM), TIME(0,0,0), MINUTE) / 60
      END) HORAS
    FROM DATAMART.DM_MKP_SELLER_DISCOUNTS_CB_DATES s
    JOIN `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS_ELEGIBLE_ITEMS` e
      on s.ITE_ITEM_ID = e.ITE_ITEM_ID
        and s.SIT_SITE_ID = e.SIT_SITE_ID
        and e.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
    JOIN (
          SELECT CAM_CAMPAIGN_ID,
            SIT_SITE_ID,
            DATE(DAY) DIA
          FROM UNNEST(GENERATE_DATE_ARRAY(DATE('2020-09-07'), CURRENT_DATE(), INTERVAL 1 DAY)) AS day
          JOIN `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS`
            ON DAY BETWEEN DATE(CAM_CAMPAIGN_START_DTTM) AND DATE(CAM_CAMPAIGN_FINISH_DTTM)
          WHERE CAM_CAMPAIGN_TYPE = 'killers'
    ) f
      ON f.DIA BETWEEN DATE(s.DIS_START_DATE_DTTM) AND DATE(s.DIS_END_DATE_DTTM)
        and f.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
        and f.SIT_SITE_ID = s.SIT_SITE_ID
    GROUP BY 1,2,3,4,5
  )
  GROUP BY 1,2,3,4
  HAVING SUM(HORAS) >= 1
),


ITEMS_DIARIOS AS (
  SELECT DIS_CAMPAIGN_ID, 
      SIT_SITE_ID,
      ITE_ITEM_ID,
      CONCAT(SIT_SITE_ID,ITE_ITEM_ID) ITE_ITEM_ID_STR,
      DIA,
      DATE_SUB(DIA, INTERVAL 28 DAY) DIA_28
  FROM (SELECT DIS_CAMPAIGN_ID,
              s.SIT_SITE_ID,
              s.ITE_ITEM_ID,
              DIS_DISCOUNT_ID,
              DIA,
              CASE WHEN DATE(s.DIS_START_DATE_DTTM) <> DIA AND DATE(s.DIS_END_DATE_DTTM) <> DIA THEN 24
                WHEN DATE(s.DIS_START_DATE_DTTM) = DIA AND DATE(s.DIS_END_DATE_DTTM) = DIA THEN TIMESTAMP_DIFF(S.DIS_END_DATE_DTTM, s.DIS_START_DATE_DTTM, MINUTE) / 60
                WHEN DATE(s.DIS_START_DATE_DTTM) = DIA THEN TIME_DIFF(TIME(23,59,59), TIME(s.DIS_START_DATE_DTTM), MINUTE) / 60
                WHEN DATE(s.DIS_END_DATE_DTTM) = DIA THEN TIME_DIFF(TIME(s.DIS_END_DATE_DTTM), TIME(0,0,0), MINUTE) / 60
              END HORAS
      FROM DATAMART.DM_MKP_SELLER_DISCOUNTS_CB_DATES s
      JOIN `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS_ELEGIBLE_ITEMS` e
        on s.ITE_ITEM_ID = e.ITE_ITEM_ID
          and s.SIT_SITE_ID = e.SIT_SITE_ID
          and e.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
      JOIN (
            SELECT CAM_CAMPAIGN_ID,
              SIT_SITE_ID,
              DATE(DAY) DIA,
            FROM UNNEST(GENERATE_DATE_ARRAY(DATE('2020-09-07'), CURRENT_DATE(), INTERVAL 1 DAY)) AS day
            JOIN `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS`
              ON DAY BETWEEN DATE(CAM_CAMPAIGN_START_DTTM) AND DATE( CAM_CAMPAIGN_FINISH_DTTM)
            WHERE CAM_CAMPAIGN_TYPE = 'marketplace_campaign'
      ) f
        ON f.DIA BETWEEN DATE(s.DIS_START_DATE_DTTM) AND DATE(s.DIS_END_DATE_DTTM)
          and f.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
          and f.SIT_SITE_ID = s.SIT_SITE_ID
  )
  GROUP BY 1,2,3,4,5
  HAVING SUM(HORAS) >= 1
),

ORDENES AS (
  SELECT ORDER_ID,
    DATE_CLOSED as DATE_CLOSED_DTTM,
    DATE_CREATED as DATE_CREATED_DTTM,
    DATE(DATE_CLOSED) DATE_CLOSED,
    DATE(DATE_CREATED) DATE_CREATED,
    SITE_ID,
    DOMAIN_ID,
    PRODUCT_ID,
    items.item.id ITE_ITEM_ID,
    CATALOG_LISTING,
    o.UNIT_PRICE,
    o.QUANTITY * o.UNIT_PRICE * o.USD_RATIO GMV,
    o.QUANTITY * o.UNIT_PRICE GMV_LC,
    o.QUANTITY SI
  FROM `meli-bi-data.WHOWNER.BT_ORDERS` O, unnest(items) items
  WHERE is_test = false
    AND DATE(DATE_CLOSED) >= '2020-08-01'
),

PRE_SSFF AS (
  SELECT SIT_SITE_ID,
    CONCAT(SIT_SITE_ID,ITE_ITEM_ID) ITE_ITEM_ID,
    SF_SALESFORCE_START_DATE,
    SF_SALESFORCE_END_DATE,
    SF_SALESFORCE_APPROVAL_STATUS,
    SF_SALESFORCE_FLAGANCELLED,
    SF_SALESFORCE_AGREED_PRICE,
    SF_SALESFORCE_REBATE,
    SF_SALESFORCE_REBATE_NUMBER
  FROM WHOWNER.BT_SF_SALESFORCE_REBATE
  WHERE SF_SALESFORCE_START_DATE >= '2020-08-01'
    AND SF_SALESFORCE_APPROVAL_STATUS = 'Aprobado'
),

SSFF AS (
  SELECT * FROM
  (
  SELECT SIT_SITE_ID,
    A.ITE_ITEM_ID,
    SF_SALESFORCE_START_DATE,
    SF_SALESFORCE_END_DATE,
    SF_SALESFORCE_APPROVAL_STATUS,
    SF_SALESFORCE_FLAGANCELLED,
    SF_SALESFORCE_AGREED_PRICE,
    SF_SALESFORCE_REBATE,
    SF_SALESFORCE_REBATE_NUMBER,
    DATE_CLOSED,
    DOMAIN_ID,
    PRODUCT_ID,
    CATALOG_LISTING,
    GMV,
    GMV_LC,
    SI,
    ROW_NUMBER () OVER (PARTITION BY A.ORDER_ID 
                        ORDER BY (B.SF_SALESFORCE_AGREED_PRICE-A.UNIT_PRICE), B.SF_SALESFORCE_REBATE ASC, B.SF_SALESFORCE_REBATE_NUMBER ) AS RANK_
  FROM  ORDENES A
  INNER JOIN PRE_SSFF B
    ON  A.ITE_ITEM_ID = B.ITE_ITEM_ID
    AND A.SITE_ID = B.SIT_SITE_ID
    AND A.DATE_CREATED BETWEEN B.SF_SALESFORCE_START_DATE AND B.SF_SALESFORCE_END_DATE
    AND B.SF_SALESFORCE_APPROVAL_STATUS = 'Aprobado'
    AND A.UNIT_PRICE <= B.SF_SALESFORCE_AGREED_PRICE
  ) T1
  WHERE RANK_ = 1
),


ITEMS AS (
  SELECT SIT_SITE_ID,
    ITE_ITEM_ID,
    ITE_ITEM_DOM_DOMAIN_ID DOM_DOMAIN_ID,
    ITE_ITEM_CATALOG_PRODUCT_ID PRODUCT_ID
  FROM WHOWNER.LK_ITE_ITEMS
  WHERE IS_TEST = FALSE
),

CUPONES_GMV AS (
  SELECT DATE(PAY_PAYMENT_DATE) DATE_CLOSED,
    SITE_ID SIT_SITE_ID,
    CAM_CAMPAIGN_ID,
    ITE_ITEM_ID,
    SUM((QUANTITY - ORD_REFUND_ITEMS)  * UNIT_PRICE)  GMV,
    SUM(QUANTITY - ORD_REFUND_ITEMS)  SI
  FROM DATAMART.DM_MKP_ORD_ORDER_COUPONS C
  GROUP BY 1,2,3,4
),

CUPONES_INVERSION AS (
  SELECT DATE(PAY_PAYMENT_DATE) DATE_CLOSED,
    DATE_SUB(DATE(PAY_PAYMENT_DATE), INTERVAL 28 DAY) DATE_CLOSED_28,
    CAM_CAMPAIGN_ID,
    SITE_ID SIT_SITE_ID,
    I.DOM_DOMAIN_ID,
    PRODUCT_ID,
    I.ITE_ITEM_ID,
    PAY_COUPON_ID,
    AVG(PAY_COUPON_AMOUNT) PAY_COUPON_AMOUNT,
    MAX(PAY_REFOUND_AMOUNT) PAY_REFOUND_AMOUNT
  FROM DATAMART.DM_MKP_ORD_ORDER_COUPONS C
  LEFT JOIN ITEMS I
    ON C.SITE_ID = I.SIT_SITE_ID
    AND C.ITE_ITEM_ID = I.ITE_ITEM_ID
  GROUP BY 1,2,3,4,5,6,7,8
),

ELEGIBLES_REBATES AS (
  SELECT c.CAM_CAMPAIGN_ID,
    C.CAM_CAMPAIGN_START_DTTM,
    C.CAM_CAMPAIGN_FINISH_DTTM,
    E.SIT_SITE_ID,
    E.ITE_ITEM_ID,
    CONCAT(E.SIT_SITE_ID,E.ITE_ITEM_ID) ITE_ITEM_ID_STR
  FROM `meli-bi-data.WHOWNER.LK_MKP_CAMPAIGNS_ELEGIBLE_ITEMS` e
  JOIN WHOWNER.LK_MKP_CAMPAIGNS c
      on e.CAM_CAMPAIGN_ID = c.CAM_CAMPAIGN_ID
),

PRE_UPLIFT_KILLERS as(
    SELECT DATE_CLOSED,
      CAM_CAMPAIGN_ID,
      SIT_SITE_ID,
      DOM_DOMAIN_ID,
      PRODUCT_ID,
      SUM(GMV) GMV_UPLIFT,
      SUM(GMV_LC) GMV_LC_UPLIFT,
      SUM(SI) SI_UPLIFT,
      SUM(GMV_28_UPLIFT) GMV_28_UPLIFT,
      SUM(GMV_LC_28_UPLIFT) GMV_LC_28_UPLIFT,
      SUM(SI_28_UPLIFT) SI_28_UPLIFT
    FROM (
          SELECT p.DIA DATE_CLOSED,
            p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
            o.SITE_ID SIT_SITE_ID,
            o.DOMAIN_ID DOM_DOMAIN_ID,
            o.PRODUCT_ID,
            SUM(GMV) GMV,
            SUM(GMV_LC) GMV_LC,
            SUM(SI) SI,
            NULL GMV_28_UPLIFT,
            NULL GMV_LC_28_UPLIFT,
            NULL SI_28_UPLIFT
          FROM ORDENES o
          JOIN PRODUCTS_DIARIOS p
            ON o.PRODUCT_ID = p.PRD_PRODUCT_ID
              and o.SITE_ID = p.SIT_SITE_ID
              and o.DATE_CLOSED = p.DIA
          where o.CATALOG_LISTING = TRUE
          GROUP BY 1,2,3,4,5

          UNION ALL
          
          SELECT p.DIA DATE_CLOSED,
            p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
            o.SITE_ID SIT_SITE_ID,
            o.DOMAIN_ID DOM_DOMAIN_ID,
            o.PRODUCT_ID,
            NULL GMV,
            NULL GMV_LC,
            NULL SI,
            SUM(GMV) GMV_28_UPLIFT,
            SUM(GMV_LC) GMV_LC_28_UPLIFT,
            SUM(SI) SI_28_UPLIFT
          FROM ORDENES o
          JOIN PRODUCTS_DIARIOS p
            ON o.PRODUCT_ID = p.PRD_PRODUCT_ID
              and o.SITE_ID = p.SIT_SITE_ID
              and o.DATE_CLOSED = DIA_28
          where o.CATALOG_LISTING = TRUE
          GROUP BY 1,2,3,4,5
      )
    GROUP BY 1,2,3,4,5
),


PRE_UPLIFT_COFOUNDED as (
  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    SUM(GMV) GMV_UPLIFT,
    SUM(GMV_LC) GMV_LC_UPLIFT,
    SUM(SI) SI_UPLIFT,
    SUM(GMV_28_UPLIFT) GMV_28_UPLIFT,
    SUM(GMV_LC_28_UPLIFT) GMV_LC_28_UPLIFT,
    SUM(SI_28_UPLIFT) SI_28_UPLIFT
  FROM (
        SELECT p.DIA DATE_CLOSED,
          p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
          o.SITE_ID SIT_SITE_ID,
          o.DOMAIN_ID DOM_DOMAIN_ID,
          SUM(GMV) GMV,
          SUM(GMV_LC) GMV_LC,
          SUM(SI) SI,
          NULL GMV_28_UPLIFT,
          NULL GMV_LC_28_UPLIFT,
          NULL SI_28_UPLIFT
        FROM ORDENES o
        JOIN ITEMS_DIARIOS p
          ON o.ITE_ITEM_ID = p.ITE_ITEM_ID_STR
            and o.SITE_ID = p.SIT_SITE_ID
            and DATE_CLOSED = p.DIA
        GROUP BY 1,2,3,4

        UNION ALL

        SELECT p.DIA DATE_CLOSED,
          p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
          o.SITE_ID SIT_SITE_ID,
          o.DOMAIN_ID DOM_DOMAIN_ID,
          NULL GMV,
          NULL GMV_LC,
          NULL SI,
          SUM(GMV) GMV_28_UPLIFT,
          SUM(GMV_LC) GMV_LC_28_UPLIFT,
          SUM(SI) SI_28_UPLIFT
        FROM ORDENES o
        JOIN ITEMS_DIARIOS p
          ON o.ITE_ITEM_ID = p.ITE_ITEM_ID_STR
            and o.SITE_ID = p.SIT_SITE_ID
            and o.DATE_CLOSED = DIA_28
        GROUP BY 1,2,3,4
    )
  GROUP BY 1,2,3,4
),


PRE_UPLIFT AS 
(
   SELECT
      CAM_CAMPAIGN_ID,
      SIT_SITE_ID,
      DOM_DOMAIN_ID,
      DATE_CLOSED,
      DATE_SUB(DATE_CLOSED, INTERVAL 28 DAY) DIA_28,
      SUM(GMV_LC_UPLIFT) GMV,
      SUM(SI_UPLIFT) SI,
      SUM(GMV_LC_28_UPLIFT) GMV_28,
      SUM(SI_28_UPLIFT) SI_28 
   FROM PRE_UPLIFT_COFOUNDED
   GROUP BY 1,2,3,4,5
   
    UNION ALL
   
   SELECT
      CAM_CAMPAIGN_ID,
      SIT_SITE_ID,
      DOM_DOMAIN_ID,
      DATE_CLOSED,
      DATE_SUB(DATE_CLOSED, INTERVAL 28 DAY) DIA_28,
      SUM(GMV_LC_UPLIFT) GMV,
      SUM(SI_UPLIFT) SI,
      SUM(GMV_LC_28_UPLIFT) GMV_28,
      SUM(SI_28_UPLIFT) SI_28 
   FROM PRE_UPLIFT_KILLERS
   GROUP BY 1,2,3,4,5
),


UPLIFT AS (
  SELECT DATE_CLOSED,
      CAM_CAMPAIGN_ID,
      SIT_SITE_ID,
      DOM_DOMAIN_ID,
      GMV,
      SI,
      GMV_28,
      SI_28,      
      SUM(GMV_DOM) GMV_DOM,
      SUM(SI_DOM) SI_DOM,
      SUM(GMV_DOM_28) GMV_DOM_28,
      SUM(SI_DOM_28) SI_DOM_28
  FROM (
        SELECT U.DATE_CLOSED,
            U.CAM_CAMPAIGN_ID,
            O.SITE_ID SIT_SITE_ID,
            O.DOMAIN_ID DOM_DOMAIN_ID,
            U.GMV,
            U.SI,
            U.GMV_28,
            U.SI_28,      
            SUM(O.GMV_LC) GMV_DOM,
            SUM(O.SI) SI_DOM,
            NULL GMV_DOM_28,
            NULL SI_DOM_28
         FROM ORDENES O 
         JOIN PRE_UPLIFT U 
            ON O.DATE_CLOSED = U.DATE_CLOSED 
               AND o.DOMAIN_ID = U.DOM_DOMAIN_ID
               AND o.SITE_ID = U.SIT_SITE_ID
         GROUP BY 1,2,3,4,5,6,7,8

        UNION ALL

        SELECT U.DATE_CLOSED,
            U.CAM_CAMPAIGN_ID,
            O.SITE_ID SIT_SITE_ID,
            O.DOMAIN_ID DOM_DOMAIN_ID,
            U.GMV,
            U.SI,
            U.GMV_28,
            U.SI_28,      
            NULL GMV_DOM,
            NULL SI_DOM,
            SUM(O.GMV_LC) GMV_DOM_28,
            SUM(O.SI) SI_DOM_28
         FROM ORDENES O 
         JOIN PRE_UPLIFT U 
            ON O.DATE_CLOSED = DIA_28 
               AND o.DOMAIN_ID = U.DOM_DOMAIN_ID
               AND o.SITE_ID = U.SIT_SITE_ID
         GROUP BY 1,2,3,4,5,6,7,8
  )
  GROUP BY 1,2,3,4,5,6,7,8
),

GENERADO AS (
  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    SUM(GMV) GMV,
    SUM(SI) SI,
    SUM(INVERSION) INVERSION,
    SUM(REFOUND) REFOUND,
    SUM(INVERSION_28) INVERSION_28,
    SUM(REFOUND_28) REFOUND_28
  FROM (
      SELECT C.DATE_CLOSED,
        C.CAM_CAMPAIGN_ID,
        C.SIT_SITE_ID,
        I.DOM_DOMAIN_ID,
        SUM(GMV) GMV,
        SUM(SI) SI,
        NULL INVERSION,
        NULL REFOUND,
        NULL INVERSION_28,
        NULL REFOUND_28
      FROM CUPONES_GMV C
      LEFT JOIN ITEMS I
        ON C.SIT_SITE_ID = I.SIT_SITE_ID
          AND C.ITE_ITEM_ID = I.ITE_ITEM_ID
      GROUP BY 1,2,3,4

      UNION ALL 

      SELECT DATE_CLOSED,
        CAM_CAMPAIGN_ID,
        SIT_SITE_ID,
        DOM_DOMAIN_ID,
        NULL GMV,
        NULL SI,
        SUM(PAY_COUPON_AMOUNT - PAY_REFOUND_AMOUNT) INVERSION,
        SUM(PAY_REFOUND_AMOUNT) REFOUND,
        NULL INVERSION_28,
        NULL REFOUND_28
      FROM CUPONES_INVERSION
      GROUP BY 1,2,3,4
      
      UNION ALL 

      SELECT DIA DATE_CLOSED,
        CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOM_DOMAIN_ID,
        NULL GMV,
        NULL SI,
        NULL INVERSION,
        NULL REFOUND,
        SUM(PAY_COUPON_AMOUNT - PAY_REFOUND_AMOUNT) INVERSION_28,
        SUM(PAY_REFOUND_AMOUNT) REFOUND_28
      FROM CUPONES_INVERSION A
      JOIN PRODUCTS_DIARIOS p
        ON A.PRODUCT_ID = p.PRD_PRODUCT_ID
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED_28 = p.DIA
      GROUP BY 1,2,3,4
      
      UNION ALL 

      SELECT DIA DATE_CLOSED,
        CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOM_DOMAIN_ID,
        NULL GMV,
        NULL SI,
        NULL INVERSION,
        NULL REFOUND,
        SUM(PAY_COUPON_AMOUNT - PAY_REFOUND_AMOUNT) INVERSION_28,
        SUM(PAY_REFOUND_AMOUNT) REFOUND_28
      FROM CUPONES_INVERSION A
      JOIN ITEMS_DIARIOS p
        ON A.ITE_ITEM_ID = p.ITE_ITEM_ID
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED_28 = p.DIA
      GROUP BY 1,2,3,4
  ) x
  GROUP BY 1,2,3,4
),

METRICAS_ELEGIBLES AS (
  SELECT e.CAM_CAMPAIGN_ID,
    DATE(DATE_CLOSED) DATE_CLOSED,
    SIT_SITE_ID,
    DOMAIN_ID DOM_DOMAIN_ID,
    SUM(GMV) AS GMV,
    SUM(GMV_LC) AS GMV_LC,
    SUM(SI) AS SI
  FROM ELEGIBLES_REBATES E
  LEFT JOIN ORDENES O
    ON E.SIT_SITE_ID = O.SITE_ID 
      AND E.ITE_ITEM_ID_STR = O.ITE_ITEM_ID
      AND o.DATE_CREATED_DTTM BETWEEN E.CAM_CAMPAIGN_START_DTTM AND E.CAM_CAMPAIGN_FINISH_DTTM
  GROUP BY 1,2,3,4
),

MANUALES AS (
  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOMAIN_ID DOM_DOMAIN_ID,
    SUM(INVERSION) INVERSION,
    SUM(INVERSION_28) INVERSION_28
  FROM (
      SELECT DATE_CLOSED,
        p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOMAIN_ID,
        SUM(SF_SALESFORCE_REBATE * SI) INVERSION,
        NULL INVERSION_28
      FROM SSFF A
      JOIN PRODUCTS_DIARIOS p
        ON A.PRODUCT_ID = p.PRD_PRODUCT_ID
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED = p.DIA
      where A.CATALOG_LISTING = TRUE
      GROUP BY 1,2,3,4

      UNION ALL

      SELECT DIA DATE_CLOSED,
        p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOMAIN_ID,
        NULL INVERSION,
        SUM(SF_SALESFORCE_REBATE * SI) INVERSION_28
      FROM SSFF A
      JOIN PRODUCTS_DIARIOS p
        ON A.PRODUCT_ID = p.PRD_PRODUCT_ID
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED = DIA_28
      where A.CATALOG_LISTING = TRUE
      GROUP BY 1,2,3,4

      UNION ALL

      SELECT DATE_CLOSED,
        p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOMAIN_ID,
        SUM(SF_SALESFORCE_REBATE * SI) INVERSION,
        NULL INVERSION_28
      FROM SSFF A
      JOIN ITEMS_DIARIOS p
        ON A.ITE_ITEM_ID = p.ITE_ITEM_ID_STR
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED = p.DIA
      GROUP BY 1,2,3,4

      UNION ALL

      SELECT DIA DATE_CLOSED,
        p.DIS_CAMPAIGN_ID CAM_CAMPAIGN_ID,
        A.SIT_SITE_ID,
        DOMAIN_ID,
        NULL INVERSION,
        SUM(SF_SALESFORCE_REBATE * SI) INVERSION_28
      FROM SSFF A
      JOIN ITEMS_DIARIOS p
        ON A.ITE_ITEM_ID = p.ITE_ITEM_ID_STR
          and A.SIT_SITE_ID = p.SIT_SITE_ID
          and A.DATE_CLOSED = DIA_28
      GROUP BY 1,2,3,4
  )
  GROUP BY 1,2,3,4
),

CAMPAIGNS AS (
  SELECT C.SIT_SITE_ID,
    C.CAM_CAMPAIGN_ID,
    C.CAM_CAMPAIGN_TYPE,
    C.CAM_CAMPAIGN_NAME,
    C.CAM_CAMPAIGN_STATUS,
    C.CAM_CAMPAIGN_START_DTTM,
    C.CAM_CAMPAIGN_FINISH_DTTM,
    C.CAM_CAMPAIGN_CREATED_DTTM,
    C.CUR_CURRENCY_ID,
    C.CAM_CAMPAIGN_BENEFITS[SAFE_OFFSET(0)] BENEFITS,
    CAM_CAMPAIGN_BUDGET_AMOUNT
  FROM WHOWNER.LK_MKP_CAMPAIGNS C
  WHERE C.IS_TEST = FALSE
)

SELECT X.DATE_CLOSED,
  X.CAM_CAMPAIGN_ID,
  X.SIT_SITE_ID,
  CASE WHEN BENEFITS.TYPE = 'VOLUME' THEN 'volume' 
      ELSE CAM_CAMPAIGN_TYPE END AS CAMPAIGN_TYPE,
  C.CAM_CAMPAIGN_NAME,
  C.CAM_CAMPAIGN_STATUS,
  C.CAM_CAMPAIGN_START_DTTM,
  C.CAM_CAMPAIGN_FINISH_DTTM,
  CASE WHEN BENEFITS.TYPE = 'VOLUME' THEN BENEFITS.CONFIGS[SAFE_OFFSET(0)].DISCOUNT_VOLUME.PURCHASE_DISCOUNT_PERCENTAGE
      ELSE BENEFITS.CONFIGS[SAFE_OFFSET(0)].REBATE_MELI_PERCENTAGE END AS REBATE_MELI_PERCENTAGE,
  BENEFITS.CONFIGS[SAFE_OFFSET(0)].REBATE_SELLER_PERCENTAGE,
  D.VERTICAL,
  X.DOM_DOMAIN_ID,
  CAST(CASE WHEN CUR_CURRENCY_ID = 'USD' THEN CAM_CAMPAIGN_BUDGET_AMOUNT * F.CCO_TC_VALUE 
    ELSE CAM_CAMPAIGN_BUDGET_AMOUNT END
    AS FLOAT64) as BUDGET,
  CAST(SUM(GMV_GENERADO) AS FLOAT64) GMV_GENERADO,
  CAST(SUM(SI_GENERADO) AS FLOAT64) SI_GENERADO,
  CAST(SUM(REFOUND) AS FLOAT64) REFOUND,
  CAST(SUM(INVERSION) AS FLOAT64) INVESTMENT,
  CAST(SUM(REFOUND_28) AS FLOAT64) REFOUND_28,
  CAST(SUM(INVERSION_28) AS FLOAT64) INVESTMENT_28,
  CAST(SUM(GMV) AS FLOAT64) GMV,
  CAST(SUM(GMV_28) AS FLOAT64) GMV_28,
  CAST(SUM(SI) AS FLOAT64) SI,
  CAST(SUM(SI_28) AS FLOAT64) SI_28,
  CAST(SUM(GMV_DOM) AS FLOAT64) GMV_DOM,
  CAST(SUM(GMV_DOM_28) AS FLOAT64) GMV_DOM_28,
  CAST(SUM(SI_DOM) AS FLOAT64) SI_DOM,
  CAST(SUM(SI_DOM_28) AS FLOAT64) SI_DOM_28,
  CAST(SUM(SSFF_INVESTMENT) AS FLOAT64) SSFF_INVESTMENT,
  CAST(SUM(SSFF_INVESTMENT_28) AS FLOAT64) SSFF_INVESTMENT_28,
  CAST(SUM(GMV_ELEGIBLE) AS FLOAT64) GMV_ELEGIBLE,
  CAST(SUM(SI_ELEGIBLE) AS INT64) SI_ELEGIBLE,
  TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL -4 HOUR) AUD_INS_DTTM,
  TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL -4 HOUR) AUD_UPD_DTTM,
  DATE(TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL -4 HOUR))  AUD_UPD_DT,
  'SCHEDULE_GAIA_SBERMEJO_TBL_MELICAMPAIGNS_UPLIFT' AS AUD_FROM_INTERFACE
FROM (
  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    NULL AS GMV_GENERADO,
    NULL AS SI_GENERADO,
    NULL AS INVERSION,
    NULL AS REFOUND,
    NULL AS INVERSION_28,
    NULL AS REFOUND_28,
    SUM(GMV) GMV,
    SUM(GMV_28) GMV_28,
    SUM(SI) SI,
    SUM(SI_28) SI_28,
    SUM(GMV_DOM) GMV_DOM,
    SUM(GMV_DOM_28) GMV_DOM_28,
    SUM(SI_DOM) SI_DOM,
    SUM(SI_DOM_28) SI_DOM_28,
    NULL AS SSFF_INVESTMENT,
    NULL AS SSFF_INVESTMENT_28,
    NULL AS GMV_ELEGIBLE,
    NULL AS SI_ELEGIBLE
  FROM UPLIFT
  WHERE DATE_CLOSED <= DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
  GROUP BY 1,2,3,4

  UNION ALL

  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    SUM(GMV) GMV_GENERADO,
    SUM(SI) SI_GENERADO,
    SUM(INVERSION) INVERSION,
    SUM(REFOUND) REFOUND,
    SUM(INVERSION_28) INVERSION_28,
    SUM(REFOUND_28) REFOUND_28,
    NULL AS GMV,
    NULL AS GMV_28,
    NULL AS SI,
    NULL AS SI_28,
    NULL AS GMV_DOM,
    NULL AS GMV_DOM_28,
    NULL AS SI_DOM,
    NULL AS SI_DOM_28,
    NULL AS SSFF_INVESTMENT,
    NULL AS SSFF_INVESTMENT_28,
    NULL AS GMV_ELEGIBLE,
    NULL AS SI_ELEGIBLE
  FROM GENERADO 
  WHERE DATE_CLOSED <= DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
  GROUP BY 1,2,3,4
  
  UNION ALL

  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    NULL AS GMV_GENERADO,
    NULL AS SI_GENERADO,
    NULL AS INVERSION,
    NULL AS REFOUND,
    NULL AS INVERSION_28,
    NULL AS REFOUND_28,
    NULL AS GMV,
    NULL AS GMV_28,
    NULL AS SI,
    NULL AS SI_28,
    NULL AS GMV_DOM,
    NULL AS GMV_DOM_28,
    NULL AS SI_DOM,
    NULL AS SI_DOM_28,
    SUM(INVERSION) SSFF_INVESTMENT,
    SUM(INVERSION_28) SSFF_INVESTMENT_28,
    NULL AS GMV_ELEGIBLE,
    NULL AS SI_ELEGIBLE
  FROM MANUALES 
  WHERE DATE_CLOSED <= DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
  GROUP BY 1,2,3,4
  
  UNION ALL

  SELECT DATE_CLOSED,
    CAM_CAMPAIGN_ID,
    SIT_SITE_ID,
    DOM_DOMAIN_ID,
    NULL AS GMV_GENERADO,
    NULL AS SI_GENERADO,
    NULL AS INVERSION,
    NULL AS REFOUND,
    NULL AS INVERSION_28,
    NULL AS REFOUND_28,
    NULL AS GMV,
    NULL AS GMV_28,
    NULL AS SI,
    NULL AS SI_28,
    NULL AS GMV_DOM,
    NULL AS GMV_DOM_28,
    NULL AS SI_DOM,
    NULL AS SI_DOM_28,
    NULL AS SSFF_INVESTMENT,
    NULL AS SSFF_INVESTMENT_28,
    SUM(GMV_LC) GMV_ELEGIBLE,
    SUM(SI) SI_ELEGIBLE
  FROM METRICAS_ELEGIBLES 
  WHERE DATE_CLOSED <= DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY)
  GROUP BY 1,2,3,4
  ) X
JOIN CAMPAIGNS C
  ON C.CAM_CAMPAIGN_ID = X.CAM_CAMPAIGN_ID
left join `meli-bi-data.WHOWNER.LK_CURRENCY_CONVERTION` F 
    on F.TIM_DAY = date_add(cast(CAM_CAMPAIGN_CREATED_DTTM as date), interval -1 day)
        AND TRIM(F.SIT_SITE_ID) = C.SIT_SITE_ID
LEFT JOIN `meli-bi-data.WHOWNER.LK_DOM_DOMAINS` D
    ON X.DOM_DOMAIN_ID = D.DOM_DOMAIN_ID
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
)
