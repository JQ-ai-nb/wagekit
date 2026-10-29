# Reproducible bonus example

Command: `node bin/wagekit.mjs examples/bonus-cliff.json`

```json
{"ok":true,"rules":"CN-resident-2026.2","year":2026,"months":[{"month":1,"taxable_cum":1100000,"tax_cum":33000,"withheld":33000},{"month":2,"taxable_cum":2200000,"tax_cum":66000,"withheld":33000},{"month":3,"taxable_cum":3300000,"tax_cum":99000,"withheld":33000},{"month":4,"taxable_cum":4400000,"tax_cum":188000,"withheld":89000},{"month":5,"taxable_cum":5500000,"tax_cum":298000,"withheld":110000},{"month":6,"taxable_cum":6600000,"tax_cum":408000,"withheld":110000},{"month":7,"taxable_cum":7700000,"tax_cum":518000,"withheld":110000},{"month":8,"taxable_cum":8800000,"tax_cum":628000,"withheld":110000},{"month":9,"taxable_cum":9900000,"tax_cum":738000,"withheld":110000},{"month":10,"taxable_cum":11000000,"tax_cum":848000,"withheld":110000},{"month":11,"taxable_cum":12100000,"tax_cum":958000,"withheld":110000},{"month":12,"taxable_cum":13200000,"tax_cum":1068000,"withheld":110000}],"total_withheld":1068000,"bonus":{"amount":3600100,"standalone_tax":339010,"combined_extra_tax":600020,"best":"standalone"},"settlement":{"tax_due":1068000,"prepaid":1068000,"refund":0,"payable":0,"bonus_merged":false,"prepaid_source":"modeled"}}
```
