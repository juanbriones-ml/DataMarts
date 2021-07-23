CREATE OR REPLACE VIEW `meli-bi-data.EXPLOTACION.BT_ORDER_COUPON`
OPTIONS (
    friendly_name = "BT_ORDER_COUPON",
    description = "Vista con informacion de montos y cantidad de cupones a nivel de orden",
    labels = [("bu","marketplace"),("track","cupones")]
) AS
SELECT
    ORD_CLOSED_DT,
    ORD_ORDER_ID,
    ORD_STATUS,
    SIT_SITE_ID,
    ITE_ITEM_ID,
    IFNULL(ITE_VAR_ID,0) AS ITE_VAR_ID,
    PARTY_TYPE_ID,
    CUS_CUST_ID_SEL,
    SUM(COU_ORD_ORIGINAL_AMOUNT) AS ORD_COU_ORIGINAL_AMOUNT,
    SUM(COU_ORD_REFUNDED_AMOUNT) AS ORD_COU_REFUNDED_AMOUNT,
    COUNT(DISTINCT COUPON_ID) AS CANT_COUPONS
FROM `meli-bi-data.EXPLOTACION.BT_MKP_COUPON_ORDER`
GROUP BY 1,2,3,4,5,6,7,8
