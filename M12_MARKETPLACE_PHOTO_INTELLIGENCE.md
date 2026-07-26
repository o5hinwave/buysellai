# M12 Marketplace Photo Intelligence Notes

Last checked: 2026-07-25

## Nano Banana Model Selection

Official Google AI docs now describe Nano Banana as a family, not one hardcoded model.

- Default image editing model for BuySell should be `gemini-3.1-flash-image` (Nano Banana 2) for balanced quality, speed, reference-image support, and production availability.
- Low-cost/latency option: `gemini-3.1-flash-lite-image`.
- Highest-quality option: `gemini-3-pro-image`.
- Legacy-only option: `gemini-2.5-flash-image`.
- Do not use preview IDs such as `gemini-3.1-flash-image-preview` or `gemini-3-pro-image-preview`; Google’s changelog says those preview models were deprecated and shut down June 25, 2026.

Official sources:

- https://ai.google.dev/gemini-api/docs/image-generation
- https://ai.google.dev/gemini-api/docs/changelog
- https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image

Implementation note: keep image enhancement server-side with the Gemini API key. The app must preserve originals, label edited versions, and use prompts that forbid changing defects, labels, serial marks, materials, colors, included parts, or condition.

## Marketplace Handoff Sources Started

Official sources checked for the first handoff slice:

- eBay selling hub and creating-listing flow: https://www.ebay.com/help/selling and https://www.ebay.com/help/selling/selling/start-selling-ebay?id=4081
- eBay creating-listing guidance: https://www.ebay.com/help/selling/listings/creating-listing?id=4105
- Facebook Marketplace selling help: https://www.facebook.com/help/153832041692242 and https://www.facebook.com/help/561376580709359
- Mercari fees/listing policy: https://www.mercari.com/us/help_center/article/169/
- Poshmark listing how-to: https://support.poshmark.com/s/article/894455911?language=en_US

Next implementation slice: turn the existing `MarketplaceOptimizationProfile` and `MarketplacePlaybookEvidence` into one versioned marketplace playbook with official post destination, official how-to destination, required fields, title limits, photo rules, and source dates for every active marketplace.
