CREATE OR REPLACE TABLE `bi-meli.DATAMART.DM_MKP_ORDERS_TOTAL_DEALS`
PARTITION BY
 DIA_SITE
CLUSTER BY
 HORA_SITE, DEAL_ID, SITE_ID, VERTICAL
AS (
  WITH DEALS AS (
    SELECT SUBSTR(A.DEAL_CHILDREN_ID,1,3) SITE_ID,
      CAST(SUBSTR(A.DEAL_CHILDREN_ID,4) AS INT64) as DEAL_CHILDREN_ID, 
      A.DEAL_CHILDREN_NAME,
      CAST(SUBSTR(A.DEAL_PARENT_ID,4) AS INT64) as DEAL_PARENT_ID,
      B.DEAL_PARENT_NAME as DEAL_PARENT_NAME,
      B.DEAL_PARENT_START_DATE as DEAL_START,
      B.DEAL_PARENT_FINISH_DATE as DEAL_END,
      B.DEAL_PARENT_STATUS DEAL_STATUS
    from `meli-bi-data.WHOWNER.LK_DEALS_CAMPAIGN_GROUP` A, `meli-bi-data.WHOWNER.LK_DEALS_CAMPAIGN` B
    where A.DEAL_PARENT_ID = B.DEAL_PARENT_ID
  ),
  ORDERS AS (
      SELECT DEAL_ID,
        DEAL_CHILDREN_NAME DEAL_NAME,
        DEAL_PARENT_ID,
        DEAL_PARENT_NAME,
        DEAL_START,
        DEAL_END,
        DEAL_STATUS,
        SIT_SITE_ID SITE_ID,
        TIMESTAMP_TRUNC(ORD_CLOSED_DTTM, HOUR) HORA_SERVER,
        DATE(ORD_CLOSED_DTTM) DIA_SERVER,
        DATETIME_TRUNC(case WHEN O.SIT_SITE_ID ='MLA' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Argentina/Buenos_Aires")
                            WHEN O.SIT_SITE_ID ='MLC' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Santiago")
                            WHEN O.SIT_SITE_ID ='MLB' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "Brazil/East")
                            WHEN O.SIT_SITE_ID ='MLM' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "Mexico/General")
                            WHEN O.SIT_SITE_ID ='MLU' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Montevideo")
                            WHEN O.SIT_SITE_ID ='MCO' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Bogota")
                            WHEN O.SIT_SITE_ID ='MPE' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Lima")
                            WHEN O.SIT_SITE_ID ='MLV' then DATETIME(TIMESTAMP_TRUNC(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), HOUR), "America/Caracas")
                            END, HOUR) HORA_SITE,
        case WHEN O.SIT_SITE_ID ='MLA' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Argentina/Buenos_Aires"))
              WHEN O.SIT_SITE_ID ='MLC' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Santiago"))
              WHEN O.SIT_SITE_ID ='MLB' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "Brazil/East"))
              WHEN O.SIT_SITE_ID ='MLM' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "Mexico/General"))
              WHEN O.SIT_SITE_ID ='MLU' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Montevideo"))
              WHEN O.SIT_SITE_ID ='MCO' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Bogota"))
              WHEN O.SIT_SITE_ID ='MPE' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Lima"))
              WHEN O.SIT_SITE_ID ='MLV' then DATE(DATETIME(TIMESTAMP_ADD(ORD_CLOSED_DTTM, INTERVAL 4 HOUR), "America/Caracas"))
              END DIA_SITE,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(0)].ID CAT_L1_ID,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(0)].NAME CAT_L1_NAME,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(1)].ID CAT_L2_ID,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(1)].NAME CAT_L2_NAME,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(2)].ID CAT_L3_ID,
        ORD_CATEGORY.LEVELS[SAFE_OFFSET(2)].NAME CAT_L3_NAME,
        ORD_CATEGORY.ID CAT_L7_ID,
        DOM_DOMAIN_ID,
        CASE WHEN ORD_SHIPPING.LOGISTIC_TYPE = 'drop_off' then 'DS'
            WHEN ORD_SHIPPING.LOGISTIC_TYPE = 'xd_drop_off' then 'XD'
            WHEN ORD_SHIPPING.LOGISTIC_TYPE = 'cross_docking' then 'XD'
            WHEN ORD_SHIPPING.LOGISTIC_TYPE = 'fulfillment' then 'FBM'
            ELSE 'Otro' end as LOGISTIC_TYPE,
        CASE
        --                    WHEN ORD_PICKUP_ID IS NOT NULL THEN 'PUIS'
            WHEN ORD_SHIPPING.MODE = 'me2' THEN 'ME2'
            WHEN ORD_SHIPPING.MODE = 'me1' THEN 'ME1'
            WHEN ORD_SHIPPING.MODE = 'custom' THEN 'Custom'
            ELSE 'Other' END SHIPPING_MODE,
        CASE WHEN ORD_ITEM.CATALOG_LISTING_FLG = True THEN True
            ELSE False END BUYBOX,
        ORD_SELLER.ID SELLER_ID,
        CASE WHEN ORD_SELLER.OFFICIAL_STORE_ID IS NOT NULL THEN True ELSE False END OFFICIAL_STORE,
        ORD_ITEM.ID ITEM_ID,
        ORD_TGMV_FLG TGMV_FLAG,
        SUM(o.ORD_ITEM.QTY * o.ORD_ITEM.unit_price) AS GMV_LC,
        SUM(o.ORD_ITEM.QTY * o.ORD_ITEM.unit_price * o.CC_USD_RATIO) AS GMV,
        SUM(o.ORD_ITEM.QTY) AS SI
      FROM `bi-meli.WHOWNER_TBL.BT_ORD_ORDERS` O, UNNEST(ORD_ITEM.DEALS) AS DEAL_ID
      LEFT JOIN DEALS D
        ON D.SITE_ID = O.SIT_SITE_ID
          AND DEAL_ID = DEAL_CHILDREN_ID
      WHERE TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 31 DAY) < ORD_CLOSED_DTTM
        AND ORD_GMV_FLG = TRUE
        AND DEAL_ID IS NOT NULL
	AND SIT_SITE_ID IN ('MLA','MLC','MLB','MLM','MLU','MCO','MPE','MLV')
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
    ),
    ITEMS AS (
      SELECT SIT_SITE_ID SITE_ID,
        ITE_ITEM_ID ITEM_ID,
        ITE_ITEM_TITLE ITEM_TITLE,
        ITE_ITEM_QUANTITY_AVAILABLE STOCK,
        ITE_ITEM_STATUS STATUS,
        CASE WHEN ITE_ITEM_SHIPPING_PAYMENT_TYPE_ID = 'free_shipping' THEN 'FS' END FS,
        CASE WHEN ITE_ITEM_LISTING_TYPE_ID_NW = 'gold_pro' THEN 'PSJ' END PSJ,
        ITE_ITEM_THUMBNAIL THUMBNAIL,
        ITE_ITEM_PERMALINK PERMALINK
      FROM WHOWNER_TBL.LK_ITE_ITEMS ITE
      WHERE IS_TEST = FALSE
      AND ITE.ITE_ITEM_ID IN (SELECT ITEM_ID FROM ORDERS)
      AND SIT_SITE_ID IN ('MLA','MLC','MLB','MLM','MLU','MCO','MPE','MLV')
    ),
    REBATES AS (
      SELECT SIT_SITE_ID,
        ITE_ITEM_ID,
        ARRAY_AGG(
               STRUCT(CAMPAIGN_TYPE,CAM_CAMPAIGN_ID,CAM_CAMPAIGN_NAME
        )) as REBATES
      FROM (
        SELECT C.CAM_CAMPAIGN_ID,
          C.CAM_CAMPAIGN_NAME,
          CASE WHEN C.CAM_CAMPAIGN_TYPE = 'killers' THEN 'Killers'
            WHEN C.CAM_CAMPAIGN_TYPE = 'marketplace_campaign' THEN 'Cofounded'
            ELSE C.CAM_CAMPAIGN_TYPE END CAMPAIGN_TYPE,
          S.SIT_SITE_ID,
          S.ITE_ITEM_ID
        FROM `bi-meli.WHOWNER_TBL.LK_MKP_SELLER_DISCOUNTS` s
        LEFT JOIN `bi-meli.WHOWNER_TBL.LK_MKP_CAMPAIGNS` c
          ON c.CAM_CAMPAIGN_ID = s.DIS_CAMPAIGN_ID
        WHERE TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) BETWEEN DIS_START_DATE_DTTM AND DIS_END_DATE_DTTM
        AND S.ITE_ITEM_ID IN (SELECT ITEM_ID FROM ORDERS)
        UNION ALL
        SELECT NULL,
          NULL,
          'Manual',
          SIT_SITE_ID,
          ITE_ITEM_ID
        FROM `bi-meli.WHOWNER_TBL.BT_SF_SALESFORCE_REBATE`
        WHERE SF_SALESFORCE_APPROVAL_STATUS = 'Aprobado'
          AND DATE(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR)) BETWEEN SF_SALESFORCE_START_DATE AND SF_SALESFORCE_END_DATE
          AND ITE_ITEM_ID IN (SELECT ITEM_ID FROM ORDERS)
      )
      GROUP BY 1,2
    ),
    COMPETENCIA AS (
        SELECT SIT_SITE_ID SITE_ID,
            ITE_ITEM_ID ITEM_ID,
            ARRAY_AGG(
                STRUCT(COMP_SITE_ID AS RIVAL_ID,
                    COMP_ITEM_PRICE AS COMP_MIN_OFFER_PRICE,
                    HOUND_URL AS COMP_URL
            )) as RIVALS
        FROM (
        SELECT SIT_SITE_ID, ITE_ITEM_ID, COMP_SITE_ID, HOUND_URL,MIN(COMP_ITEM_PRICE) AS COMP_ITEM_PRICE,
        FROM `meli-bi-data.COMPETENCIA.LK_COMPETITIVE_ITEMS`
        GROUP BY 1,2,3,4
        )
        GROUP BY 1,2
    ),
    PROMOTIONS as (
      SELECT SIT_SITE_ID,
        ITE_ITEM_ID,
        STRUCT(PROMOTION_TYPE, LANDING_POSITION) PROMOTIONS
      FROM (
        SELECT Y.SITE_ID SIT_SITE_ID,
            CAST(SUBSTR(Y.ITEM_ID,4) AS INT64) ITE_ITEM_ID,
            MIN(Y.POSITION_RANK) LANDING_POSITION,
            MIN(Y.DEAL_TYPE) PROMOTION_TYPE
        FROM (
              SELECT SITE_ID,
                    MAX(CREATED_DATE) LAST_UPD
              FROM `meli-bi-data.ML.BT_PROMOTIONS_LANDING_SCORE`
              GROUP BY 1
        ) X
        JOIN `meli-bi-data.ML.BT_PROMOTIONS_LANDING_SCORE` Y
            ON X.LAST_UPD = Y.CREATED_DATE
              AND X.SITE_ID = Y.SITE_ID
        GROUP BY 1,2
        order by 1,3
      )
    ),
    PRICES AS (
     SELECT I.SIT_SITE_ID,
        I.ITE_ITEM_ID,
        MIN(ITE_ITEM_PRICE_AMOUNT) PRICE,
        MIN(ITE_ITEM_PRICE_REGULAR_AMOUNT) REGULAR_PRICE
      FROM `bi-meli.WHOWNER_TBL.LK_ITE_ITEM_PRICES` I
      WHERE ITE_ITEM_PRICE_API_STATUS = 'ACTIVE'
        AND (TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) BETWEEN ITE_ITEM_PRICE_START_TIME_DTTM AND ITE_ITEM_PRICE_END_TIME_DTTM
          OR ITE_ITEM_PRICE_TYPE = 'standard')
        AND ITE_ITEM_ID IN (SELECT ITEM_ID FROM ORDERS)
	AND SIT_SITE_ID IN ('MLA','MLC','MLB','MLM','MLU','MCO','MPE','MLV')
        GROUP BY 1,2
    ),
    ITEM_DETAIL AS (
      SELECT I.*,
        R.REBATES,
        C.RIVALS,
        P.PRICE,
        P.REGULAR_PRICE,
        M.PROMOTIONS
      FROM ITEMS I
      LEFT JOIN REBATES R
        ON I.SITE_ID = R.SIT_SITE_ID
          AND I.ITEM_ID = R.ITE_ITEM_ID
      LEFT JOIN COMPETENCIA C
        ON I.SITE_ID = C.SITE_ID
          AND I.ITEM_ID = C.ITEM_ID
      LEFT JOIN PRICES P
        ON I.SITE_ID = P.SIT_SITE_ID
          AND I.ITEM_ID = P.ITE_ITEM_ID
      LEFT JOIN PROMOTIONS M
        ON I.SITE_ID = M.SIT_SITE_ID
          AND I.ITEM_ID = M.ITE_ITEM_ID
    ),
    DOMAINS AS (
        SELECT D.DOM_DOMAIN_AGG1,
            D.DOM_DOMAIN_AGG2,
            D.DOM_DOMAIN_AGG3,
            VERTICAL,
            SIT_SITE_ID SITE_ID,
            SUBSTR(DOM_DOMAIN_ID,5) DOM_DOMAIN_ID
        FROM `bi-data.WHOWNER_TBL.LK_DOM_DOMAINS` D
    ),
    ORDENES_VERTICAL AS (
    SELECT O.*,
        D.DOM_DOMAIN_AGG1 DOM_AGG_1,
        D.DOM_DOMAIN_AGG2 DOM_AGG_2,
        D.DOM_DOMAIN_AGG3 DOM_AGG_3,
        VERTICAL
    FROM ORDERS O
    LEFT JOIN DOMAINS D
        ON O.DOM_DOMAIN_ID = D.DOM_DOMAIN_ID
            AND O.SITE_ID = D.SITE_ID
    )
    SELECT X.*,
      ITEM_TITLE,
      STOCK,
      STATUS,
      FS,
      PSJ,
      THUMBNAIL,
      PERMALINK,
      PRICE,
      REGULAR_PRICE,
      REBATES,
      RIVALS,
      PROMOTIONS
    FROM (
      SELECT DEAL_ID,
          DEAL_NAME,
          DEAL_PARENT_ID,
          DEAL_PARENT_NAME,
          DEAL_START,
          DEAL_END,
          O.SITE_ID,
          DIA_SITE,
          HORA_SITE,
          DIA_SERVER,
          HORA_SERVER,
          VERTICAL,
          CAT_L1_ID,
          CAT_L1_NAME,
          CAT_L2_ID,
          CAT_L2_NAME,
          CAT_L3_ID,
          CAT_L3_NAME,
          DOM_AGG_1,
          DOM_AGG_2,
          DOM_AGG_3,
          DOM_DOMAIN_ID DOMAIN,
          LOGISTIC_TYPE,
          SHIPPING_MODE,
          BUYBOX,
          INICIATIVA,
          SEGMENTO,
          ASESOR,
          SELLER_ID,
          SELLER_NICKNAME,  
          OFFICIAL_STORE,
          O.ITEM_ID,
          TGMV_FLAG,
          SUM(GMV_LC) GMV_LC,
          SUM(GMV) GMV,
          SUM(SI) SI
      FROM ORDENES_VERTICAL O
      LEFT JOIN `bi-meli.DATAMART.DM_SELLERS_DEALS` S
        ON O.SELLER_ID = S.CUS_CUST_ID_SEL
      GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33
    ) X
    LEFT JOIN ITEM_DETAIL I
      ON X.SITE_ID = I.SITE_ID
        AND X.ITEM_ID = I.ITEM_ID
);
