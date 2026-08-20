import Foundation

enum HTTPFixtures {
    static let tickerList = """
    {
      "results": [
        {
          "symbol": "MXRF11",
          "name": "MXRF11",
          "longName": "Maxi Renda Fundo de Investimento Imobiliario Cotas",
          "assetType": "fund",
          "subType": "fii",
          "exchange": "B3",
          "currency": "BRL",
          "sector": "Miscellaneous",
          "subsector": "Logística",
          "isActive": true,
          "logoUrl": "https://icons.brapi.dev/icons/BRAPI.svg",
          "quote": {
            "lastPrice": 9.29,
            "changePercent": 0.43,
            "volume": 1899639,
            "marketCap": null
          }
        }
      ],
      "pagination": {
        "page": 1,
        "limit": 1,
        "totalItems": 1,
        "totalPages": 1,
        "hasNextPage": false
      }
    }
    """

    static let quote = """
    {
      "results": [
        {
          "symbol": "KNRI11",
          "shortName": "KNRI11",
          "longName": "Kinea Renda Imobiliaria Fundo de Investimento Imobiliario",
          "regularMarketPrice": 153.48,
          "regularMarketChangePercent": 0.97,
          "regularMarketVolume": 66189,
          "regularMarketPreviousClose": 152,
          "regularMarketDayHigh": 154.2,
          "regularMarketDayLow": 151.8,
          "fiftyTwoWeekHigh": 170.1,
          "fiftyTwoWeekLow": 130.4,
          "marketCap": null
        }
      ]
    }
    """

    static let dividends = """
    {
      "dividends": [
        {
          "symbol": "MXRF11",
          "approvedOn": null,
          "label": "RENDIMENTO",
          "lastDatePrior": "2025-12-01 00:00:00+00",
          "paymentDate": "2025-12-01 00:00:00+00",
          "rate": 0.08941643,
          "relatedTo": null,
          "isinCode": null,
          "remarks": "backfilled from FiiMonthlyReports"
        },
        {
          "symbol": "MXRF11",
          "approvedOn": null,
          "label": "RENDIMENTO",
          "lastDatePrior": "2025-11-01 00:00:00+00",
          "paymentDate": "2025-11-01 00:00:00+00",
          "rate": 0.098144606,
          "relatedTo": null,
          "isinCode": null,
          "remarks": "backfilled from FiiMonthlyReports"
        }
      ],
      "requestedAt": "2026-02-08T16:25:19.026Z",
      "took": 23
    }
    """

    static let yahooChart = """
    {
      "chart": {
        "result": [
          {
            "meta": { "symbol": "CPTS11.SA" },
            "events": {
              "dividends": {
                "1": { "amount": 0.08, "date": 1 },
                "1786971600": { "amount": 0.09, "date": 1786971600 }
              }
            }
          }
        ],
        "error": null
      }
    }
    """
}
