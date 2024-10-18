//
//  PortalWebView.swift
//
//  Created by Portal Labs, Inc.
//  Copyright © 2022 Portal Labs, Inc. All rights reserved.
//

import AnyCodable
import UIKit
import WebKit

/// The expected response from portal.provider.request
public struct PortalProviderResponse: Codable {
  public var data: String
  public var error: String
}

/// The result of PortalMessageBody.data
public struct PortalMessageBodyData {
  public var method: String
  public var params: [Any]
}

/// The unpacked WKScriptMessage.
public struct PortalMessageBody {
  public var data: PortalMessageBodyData
  public var type: String
}

/// The errors the web view controller can throw.
enum WebViewControllerErrors: Error {
  case unparseableMessage
  case MissingFieldsForEIP1559Transation
  case unknownMessageType(type: String)
  case dataNilError
  case invalidResponseType
  case signatureNilError
}

/// A controller that allows you to create Portal's web view.
open class PortalWebView: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
  public var chainId: Int
  public var delegate: PortalWebViewDelegate?
  public var webView: WKWebView!
  public var webViewContentIsLoaded = false

  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  private var eip6963Icon: String
  private var eip6963Name: String
  private var eip6963Rdns: String
  private var eip6963Uuid: String
  private var portal: Portal
  private var url: URL
  private var onError: (Result<Any>) -> Void
  private var onPageStart: (() -> Void)?
  private var onPageComplete: (() -> Void)?

  /// The constructor for Portal's WebViewController.
  /// - Parameters:
  ///   - portal: Your Portal instance.
  ///   - url: The URL the web view should start at.
  ///   - onError: An error handler in case the web view throws errors.
  public init(
    portal: Portal,
    url: URL,
    onError: @escaping (Result<Any>) -> Void,
    eip6963Icon: String = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAPoAAAD6CAIAAAAHjs1qAAAABGdBTUEAALGPC/xhBQAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAA+qADAAQAAAABAAAA+gAAAACOvM8JAAAZaUlEQVR4Ae2debgU1ZnGq7puXbjs+yK7oCCCgBEFFxCcR5nEIYv7NsZlonIdhFHijIM6gpOMawC5GPc4ahBJ4sZk0CeyiUAC6kWQAAFBQPZNdnudt2npuUJ33z6nTp86y1d/aNN96tT3ve/vnq4+dRZ30OgjDh2kgB0KROxIk7IkBdIKEO7EgUUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2pEu7EgEUKEO4WmU2plpEEQRQ4u0dkSJ/Iqe0jjeo7+w46qzYl5yxN/mVlMkid2XNR+dC+kW7tIk0bOq7jROPOtDmJN+cnsgXoBasCLm1WwypZpnybZu6/XV3Wt1uOr8fl65PjX41v3Z3iqxlntW3mjr2+rFfnHJVXr03+cmqgyrmjMuBEwp3HxPNOj9x3rd+gIu+5+w45IydH123lIf7ktu7EEX6j+mjQcx8HDju/nBqbv1zMd0juaxj6rtdp4FhDUytJWq7r3Hixd/cVfh2/UP34dMBpkRmLEnHGW4+KOs7kO8ubN87LOq5a7jtD+3q4v1n6Bc+fU6G4Tf8sx9el6Snz5+eXOfdf5988rAzQ13rgbueaIcw/jXAKTqy1cgRw0yVl91/vIyQ6ileAcC9Wq0b1nCdu8y86k0GxSwdEivnDyEaAwj8YwFD/Rf0iT97uIzA6ilSAQdwiazSy2EnN3aqR5X26ssnVorHbqVXtTXVWMRRu0YihPE484+QIAkN42UroRQEF2PwrUJHBH3Vr504Z6XdkATerRqumDCAyFc5eAoEhPASZfYde5FOAcM+nzLfv9+0amVRZ3rQhJ0x1y2upv+bHTIVrnojwEGTOXtGaxeg14V6IgQt6Rx67za9ft1AZRT5DkI//zEfAisSjZhikTl5ffnCON+5Gv1yfrg/00iDgSwd4eVOy/gN9zJRr1ZWDvcof6idOJOKMubIMLT2GG8gVTI+r6eeoBF3Rs45nSRIuVKJLjBgO4t0XZ8ZLVL++1RLu3/EOPd9o1K8YpDHrmXzw54o2fvLb8RQ9eK3hMOH+/2JE3PSdwPfP0Z71TEqXD/Lq1XEemx5P0uCaYyYT7t8q4UWcsdf7GHB7TBkT/o8/3bp13IdfjSWI+KN+GuUuN6G+5zx0o2msZ9TAH/C4n/pIkA4oQLg76Gr8xS0m91if3yuCBAsP4bTkj8F23PEg89Gf+Zg3ZLbfSPCRf/K5n9oaI47hNhf2CX0XT9zu98s1I6nwiTp+ijSRLFK2+bAXd8xFeuL28pwT5EwFAsk+eXt5gUlYpiaezctS3DFG/Fd3lJ/WkXPgV1Y+7V706OgicWuHyNuIe+P67q9GlJ/a3jrWM3+cSHzCiPImDWxM3zrcMVZ2YqXf7SQbzc5+F3U9CcT73KOas/Vo98Iu3Js3wrhwv0sbq1nPMAoRIAUE0Q7ZIAFbhDvmxaFd55uUFERiZc+FFBAEMwyVjVB4YLbg3rKJO+lOv0NLi6wthhUIgjYe4hRT2IAyVuDeCqxX+u1a2GIqE5eQBeJAIqazNC1sPu6tm6bb9bDm6sdYxpwzFRYIHMSBRBBKYJ1qVmU47liiCE0XllwMS/1d+xjGm+9mKSw2I0gEoYpZ0UnsdSXXZjLuGdZDtPDgEWfdFgbcv9iSwilhHaHLJSFxY3HPmBfuF/Ts6kSMZcooCuMUCa7nu0T6xs/oNt5M3FVg/fA3zsvvM7P7m/cTODHEI0N8iLd/Jc3dQNwzt6HhtuuYL/fwa7HtexnuZDI279ibwonhTreDdOiPN5J403CHSbAqXNb3HUzd+zz/+utYuB2no5KStnOFKzeVeKO2Mwj9Hmb9thRuvn83L4EdBwIeGJh+xWDvwj5e59Yu0zLCAa9b8/Rte1Ijq2JBtiGpWZsKr83BHQ3SU+I6j3fvT/11Q+qrnaktu1JbdqeA7+Fo6kjUydc1nkw5e/enmH6YFmk/ppk2buBi5njOAyuHYY5SRbmLUez4a0cPOh4b9ejgihoMYxjxhuAO1oN3KaATcNGK5IIVieXrU7o3aRCkdxf33J7egJ6RgDOYIAXaeHCf8+9NrzdNwD3gjSYaZlD+zsLEklXJUjTP4QKBL4ezukf+YaA3sGcEC+nwHfh+u8sI4rXHHYM98NuUb4wAtm5866PEHz5MwE4+DjQ6C7c6l13g/eg8j2+RV0g0cjJPX5NSEumNe3qcIxfraNHfW5x4YWYCHX9K+VHqYKDYzZd4w/p7WDyV9di8K31Xo7ViGuOO8esY2MQxzhHd4eNeiS9bZ+/KWr27RB64oYxjFCR+u6ON3xne2B7WP9HjyrP/jR9XQUj/RM/DBK4xvQs+T97yeNRm1uEY0ocIkILVPTQukF1Utw/r1YOX13Jf1WZH55uyzkvCFqdPvxuf9Gb8m1hw3bSvASJ88Gny4GGn3ymRfL2cOZPExHb86p27NHk4mvNzpd/Ur3Vv2iA9rZiVdXz/Vj4VfWMu8yAWpd0LHNz0eYnKSVHWmxOIn57ZreFaBprhnl4z4w6/U2u2HjUMOh9VFVu5wa5fpUX+LazamBaHlXhYACNgR5FXUaSYTrg3qu8+eYffpS2bxHv2p0ZNiW3cQaznRQ7igHgIlbdErg9gBIiHKbk+VPQ9bXBvWOFgh2jW9WHw2GjsS/EN29mMVNSrUoYF4iEU61M2rFcDU2CNLoceuB9du7T8FPadcif8Pr58PXP/gy7miY0TQkEu1jphCpbaDDhOgfWi3OU1wB07rjx+m9+9A/OX5uzq5IxF9NuUgQ3INauauXWANTAINql/qI57RZ30+us9OzHHifHiE//A3Fapb1ipI4RoHEPtYRBsglmKH8wYycwHQ1v/61YfjwA5Llr1TmLPAbplZ1Zu74EUpGM+zXFg0yO3qr5jAg9JHFpwnJLZQ6ZvV54IMc3i/SU8nnHEad4pkA4CcuTVp2t6Vxy+IWgcl+M4hQcmjsuwnoJZC/95s/+9UzjDe2lmHIPA6OBTANJBQL5zYRmMg31qHpw8lTSZMs/BZnHc+yVhGNPcz5h/b5U0I+0qh4CQkS9sGAf7YKKCh3K4Y/zGgzf45/bkD+yPf07QVtEBUYOAkJG7EtgHE5mG4nBfi+lEfqqYLlNkYcxBvu9af9AZ/FFhyYqZi6lpL1LvQsUgY5D1P2AirAxrUnm+xPjByldjkPfv/GHZ350ZKCQ8K2Ed/hEkYIPPhYwBn9DBShiqlESB2BKbybVDvcsHBb3jW7KamnZhtgQXE4bCVmEBBa5IFdwxney2SwW0BB+v5vyBFVhJAysQIiZs/fv+qhCvBO7Y7/PnVwlgHfeaqzZS6y7sDw9iBrl9z8Yx5qoyRfavDR93jKfDvEkhv+Ixd5h1TF/WEnpxogIQE5Ke+D7rOzAXFqswcDJ83O+9WtiSjjTQlxXEWsuLkhRrAcHoWi9X6gIh4/7j870LeguLQfelv0ptNkf9AiWF0bCbIwaBpwhDjSMmLPQzYriAW/bspQ+GujJ6NgyTXoiVFHaHu452mLijU1bscKJDRwTcaJoEa/BcxEoKuytD7YkPDff+3SMCb2Myvuq4FERwIktag3BJYTqsL2nMBSoP58IYPzTyxyJvYzIZCuk1KyCWhR+VQlJYH9YAsnBwHz7QY10oxkLUTE0Z1gOAULILAXf0wl51YTjZhiIxXfREBa4e4gl50nJizYXfCQH3IX0j6JMpHBZ9arYC6IYf2i8E9kK45DVDxd+1mw2HkdldMyQEDGTjjl/lrEsjGWk2JYUlmeR30cjGHSMfyWlSIKOAfBik4o6FNM7vJfWKBJbKCgAGICHzkArfeafLTk+mlHQtVgXAOpBgPStIeakXu+hMupMJYpaB50pGQh7uWHvk7PCeHhtIihEp4deqzEVp5OGOZQRlJmYEDOYngUFjHAuAcusiD/c+J9OjJW6bTD5RJhjycOdb7dFknym3owrIBEMS7ti09vTOkq5FFAlUQMK6SACDY09jvhwlIdimqSu5h5VPDjrrOAUkLD8IMIDHcdct0T8l4d6+paR8SiQTVVtSBaThIQv3FoR7SYHRu/L2svCQhTu17noDWdroTWvdMb65tIJR7TorIA0PSa27LhsR6syMxrFLw0MS7hXl1LprjGOpQ5eGhyzcld+CsNSOUv0FFJC2QyXhXsAF+kiSAqbhLkk2ugwpUFABSa37YVq9saANln8oDQ/C3XLSlEjfNNwPfUOLlSoBlppBSMNDUut+iG5m1ARNjaik4SEJ9217qHVXgywlo5CGhyTcN+0g3JUETY2gpOEhC/edhLsaZCkZxSZZeMjCnVp3JTlTJCjTWvete1JHoopoS2EwKCBh8h7AAB4MMQUoKql1xyYQy9fTBr8BjArpVAmT9z5fL2az4mIUkoQ7Qlm6lnAvxhHrylRLBEMi7l9I+sKyjhfNE14qEQx5uK/4MhmNa+4MhS9aASABMETXmrc+ebjH4s7iVfISy5sxfaCSAkACYEg75OGOlD74JCEtMbqQFgr86WOpSEjF/aPPk9QdqQWFcoLEQMgFK6R+4UvFHazPXy41PTm20VX4FAAMkps/qbhDlJmLpX558dlAZ8lR4L0lsmGQjTt+mqzdTD2ScnBS+iprNqfkd13Ixh0OTJ0t8ae40o5bHdzUWSFgEALusz5NShvfbDVQCie/dXdqdnUIv+JCwD2RdF6fLfumTWHrbQxt2pwEMJB/hIA7knxnYWLDdrqDl2+3EleE9QAglFDCwT2ecJ56S/ytm7RNIEKxKpSLlkLSSW/GAUAoRzi4I9W/rEx+uEzw91mF3C2YQzFM8kWFSwrT5XfIZEULDXdEUPV2XOygsXp1aeHVrLNiXoiVFHZPflv8t3rxqYaJ+5bdqSnviEy+Pi28WrzzxZUUKykaOPTJFHflkpQKE3ck9Ob8hMBbmjbNqHUXTIlASWH0Wx+FdM9+TJWQcUcYj7weE9UN37EV4X7MWEH/FyUpLIbRgoLiryZ83Pcfdsa9EhfSC3tSc9f3+LWgM49TAGJC0uPe5PgnzIXFMDr0I3zcIQFmbT82TcBNPHrNundQIqPQfRUSAMQU0hH56LS4IhPzVYHjfxcnnpkhgPjvnSqgNRLCigGVCBETtqozDFYV3AHHb2clfjcv6E+Zs05VKCPdiQ8u5vR5Cdiqjg5qwYFO2T99EujZU6/OkRaNqIEXABhkhJhBKoKV6HkMUoPwcwPlIzwaLOLzi9/G5n3GTzzuNYf1Vysp4SrJqRAyBrlxh4mwUsKqTExqKEcGfsU/9EosyBTG75/jSVjqjUll7QpDQMjIHfaCz5MwUUhvG3cMOU9UDndEifFDD/wmhkE1OSOu9c12LdzBZ6iYV62Rq1MAAkJGvnhg3AMvx8IaBFY4ZkWxwNoj//5i7OO/cRJ/07CyCKdZheWy4lNIBwH5UoVlME7m0jFMcSqKO3LAcKL7XojxrSzZubV78Vn838VMCppXGNJBQI68sNojLBM77I8jjAKnqIs7gsaqDPc+H1u2jqeNrxzuNWnA41kBsWz4qGkDF9JxZAqb/vX5mOSFNFjjVBp3JIOVd+59LsaxjGCj+u5dP+H8RmYV0aTyEA3SsWYEg37+bEzafpGs4WXLq447Aj14xLnnmdiqjcwDR4f2jVw6gKehyqpj2wvINaQvMxKwBgZJ2z0viCnMuQW5GPe5IP7uX0f/9hUz8aMuKwv4rIQ7Zu1OhFCQizVsmAJrYJAWhx64Q0qMp/uXX8dYl2TCmL6Hbyrr0JL521kL8wQGiYG+EIp1PCnsgCkqDHUsUgptcEc++w6mRj8dW7eFrY1v2tCdUOkT8QWAgDgTRvgQqkCZEz+CEbADppz4kbLv6IQ7RPz6KPFfbmOTGMM/QHz3Dmx2KuuZ2MB6dEyL05xxoNH6bWnWYYfYYEpdm9dp4NhSX0Ns/ejqmvtZ8tzTI41ZOhDq1XGHne2h62DFl5o5JFa942q7crB3/w1+wwq2hgALxYyaEttzQD8l9cMdhh2OOhiBxEq8F3HO7hHp3j6ChR++CX8e2XHgyf5no3rOf/yjf9kFHmRhOjbuSLO+e79+rCNNxlyZhCll4V370qJ/xb7bMv5IXrinvHcXXRMXIirShwiQgrU2CD6qKgbxWU9UpLw7aLQmfUi5BGvZxJ1U6XPMp8Q+r5hi8+J7iR17dXUulx61vwfFbhnmXdLf4xhTtHlXamRVTGvF9MYd9rYC8Xf6bbmW3MDoDiwF8fsPE+EuflI7pCJKQKKfXOD96DyvnLlvPX15sH5XVWy75q2D9rjDidZN3YmVnMTj9GTKWbgi+e7CxBLsAqfQRLM0ZMEPdKWf1T0yfKA3oGeEo0XPBIAFsMC6qPVRgifFXYMJuCN5EI+7moBrAOHR4KIVyQUrEsvWpXS3FlL06uye2zNNef263HikT8RXH+5hdBckI4EhuCMZGAziwX0msYD/xa+xlRtT+GWGL3H4vf8Qhmem0COUb9YCZu58fSBVii8HNM9NGrr5Gma/zKlb7lSUuw0qHNyutG3uYlrGaR3dZozPjPLJBcr/ebIhrCNHc3BHMmKJz0dAvvcxLxMPX2ZXp9dTCD6GBE3yFYO9C/t4XdqI+QPOF3aB98E62nWTftgYhTucQwuH+3hRbXwBFAp8hOfq41+Lc08+RM14PnD/dTwDcQtExfoRWMf9Ou7aWU9UuTxzz6vKySA2FX5UYbz4I7f65/fi1BYn4nSOQecCrTGSdejDaYlAZYVXpQLxWLJi7HU+OrlZs0O/Kk4MsuIF6xVPLJ+5hzGsXc+kaSDuSAxWhd6ZUFHH+enFzJNLbrzYw4khHubdr9cU00zckaEK3WdD+npMI8hRGKfUtEfya7NZh5jG4p4lPsSOBfSudGnLcD9zcls3YB95kD+PTAMRolxBgi/yXJNxzxIf4m0o0zhypsJFGlxkscztn9msQwrDcUeG6S/oyTE8LSrSeLHF8Bio+KOMpXDx1dZaMj32y6BnSQXyNR93JI+BTfjlyjFauIBwxnwEWSCO7mO/irTDCtyhBYatwlRMTShSF0uKQRC061qP6WVyyhbcIcrOr9OPCWlz+iwfkAKC7NR2rkY2keJfWIQ7RMHAL7Tx67ZSG+9ABEih77yk4hGvWdIu3JH5nv3pWX+s69XUlMyA12s2p9t1SGFALkwpWIc71Nl7AMRHV2+yzuwMGUh89JSodmtmMGGdr7CNuEOLfYec0U9HV26wjvi/bsD6MFGkb+dhKe4w+0B6Fb6oIvt9yoEPa1JjPUckbu1hL+6w/OhKq7FP1/CsH68dMUgT6/QGn3eiXeI1A7YadwiR3jHhOf59oGpKqfJrzDXB+uuK7zUgQUDbcYfEWFEMW6zMX25sG//hMtX3kJEAeuYShHtaB0ypxl5/s6oNJB5JPfhyrBRzxqUxKvBChPu3YmIpgfGvxv74Z6MWmkE645Xc31QgwUxVhTQGjylGWYWxkt6jb8Sx6crlg8KcYyEq3enzEtijXbV9q0Vlx1cP4f4d3QDHU2/F0X2BSXTf+UC3f7z8fuLFmXHdoi55vIR7DokBysEjqRHDdRUHjfobc426K8thEtdbujrKlSzDSdPmpJdGuvvysnAXBWCI+GhR3I89Pj3+P2b9AmEVoUB5wj2vODMWJTCw5MEbfKYZSXmrK/0HWNB43CsxdDuW/lK6XoF6Zgo5B3TueVaPJ5H4LhrzDLFeyE18RrjXIlD1muRdVVHusbJMDzKZCteMG+GNrIpWr6V2vaYqOV4T7jlEOe4t7JQ7YhLnNKjtexgGXTIVzgaJSUl3TIytYd9jOVuDPS8I96K8xlz9yknRz75gaz4xL+7L7Qy4ozBmGBYV0LFCCAmBhbiyyLFA9Pg/4V6sTxgjjh2iP/iUgfgZC5NMT3lQeMYihvo/+CSJkKwdvF6sczXKEe41xKjtZSyeHmjw0ntFPapEi/v6HOYHPVNnx4tZ2wh/GHg4MP61GEKio3gFtNxXtfj0SlGyem0Kcz3P6eGV+3mrxxLv6NLZsTdvgXwfYHeQj1cnh/bz6uSvHPMzHvrv2Lss3wP5Lmfb+4Q7j+P4dTi7OtmtnZtzNyjMkBrzbJx7TZu9B5w51Uns3Y7Fr08MDj1FY56LYQ7eiR/RO7UqYNruHbUmLLYAttkY0idySnvsWO98fdBZ81USA26D7NtRMzxUfmGfSPcOEexwve+gs3pTcvZSYZXXvJA9rwl3e7ymTOkxEzFgkwLUM2OT29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CQA4W6T29bnSrhbj4BNAhDuNrltfa6Eu/UI2CTA/wHlhdoM4ijZvwAAAABJRU5ErkJggg==",
    eip6963Name: String = "Portal MPC Wallet",
    eip6963Rdns: String = "io.portalhq",
    eip6963Uuid: String = "d73d7104-7e24-442b-913b-1147cd8e0325"
  ) {
    self.chainId = portal.chainId ?? 11_155_111
    self.eip6963Icon = eip6963Icon
    self.eip6963Name = eip6963Name
    self.eip6963Rdns = eip6963Rdns
    self.eip6963Uuid = eip6963Uuid
    self.portal = portal
    self.url = url
    self.onError = onError

    super.init(nibName: nil, bundle: nil)

    guard let address = portal.address else {
      print("[PortalWebView] No address found for user. Cannot inject provider into web page.")
      return
    }
    do {
      self.webView = try self.initWebView(address: address)
      self.bindPortalEvents(portal: portal)
    } catch {
      print("Error initializing WebView: ❌ \(error.localizedDescription)")
    }
  }

  /// The constructor for Portal's WebViewController.
  /// - Parameters:
  ///   - portal: Your Portal instance.
  ///   - url: The URL the web view should start at.
  ///   - onError: An error handler in case the web view throws errors.
  ///   - onPageStart: A handler that fires when the web view is starting to load a page.
  ///   - onPageComplete: A handler that fires when the web view has finished loading a page.
  public init(
    portal: Portal,
    url: URL,
    onError: @escaping (Result<Any>) -> Void,
    onPageStart: @escaping () -> Void,
    onPageComplete: @escaping () -> Void,
    eip6963Icon: String = "data:image/png;base64,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",
    eip6963Name: String = "Portal MPC Wallet",
    eip6963Rdns: String = "io.portalhq",
    eip6963Uuid: String = "d73d7104-7e24-442b-913b-1147cd8e0325"
  ) {
    self.chainId = portal.chainId ?? 11_155_111
    self.eip6963Icon = eip6963Icon
    self.eip6963Name = eip6963Name
    self.eip6963Rdns = eip6963Rdns
    self.eip6963Uuid = eip6963Uuid
    self.portal = portal
    self.url = url
    self.onError = onError
    self.onPageStart = onPageStart
    self.onPageComplete = onPageComplete

    super.init(nibName: nil, bundle: nil)

    guard let address = portal.address else {
      print("[PortalWebView] No address found for user. Cannot inject provider into web page.")
      return
    }
    do {
      self.webView = try self.initWebView(address: address)
      self.bindPortalEvents(portal: portal)
    } catch {
      print("Error initializing WebView: ❌ \(error.localizedDescription)")
    }
  }

  /// The constructor for Portal's WebViewController.
  /// - Parameters:
  ///   - portal: Your Portal instance.
  ///   - url: The URL the web view should start at.
  ///   - persistSessionData: Will persist browser session data (localstorage, cookies, etc...) when enabled.
  ///   - onError: An error handler in case the web view throws errors.
  ///   - onPageStart: A handler that fires when the web view is starting to load a page.
  ///   - onPageComplete: A handler that fires when the web view has finished loading a page.
  public init(
    portal: Portal,
    url: URL,
    persistSessionData: Bool,
    onError: @escaping (Result<Any>) -> Void,
    onPageStart: @escaping () -> Void,
    onPageComplete: @escaping () -> Void,
    eip6963Icon: String = "data:image/png;base64,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",
    eip6963Name: String = "Portal MPC Wallet",
    eip6963Rdns: String = "io.portalhq",
    eip6963Uuid: String = "d73d7104-7e24-442b-913b-1147cd8e0325"
  ) {
    self.chainId = portal.chainId ?? 11_155_111
    self.eip6963Icon = eip6963Icon
    self.eip6963Name = eip6963Name
    self.eip6963Rdns = eip6963Rdns
    self.eip6963Uuid = eip6963Uuid
    self.portal = portal
    self.url = url
    self.onError = onError
    self.onPageStart = onPageStart
    self.onPageComplete = onPageComplete

    super.init(nibName: nil, bundle: nil)

    guard let address = portal.address else {
      print("[PortalWebView] No address found for user. Cannot inject provider into web page.")
      return
    }
    do {
      self.webView = try self.initWebView(address: address, persistSessionData: persistSessionData)
      self.bindPortalEvents(portal: portal)
    } catch {
      print("Error initializing WebView: ❌ \(error.localizedDescription)")
    }
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func bindPortalEvents(portal: Portal) {
    portal.on(event: Events.ChainChanged.rawValue) { data in
      if let data = data as? [String: String] {
        let chainIdString = data["chainId"] ?? "0" // Get the string value, defaulting to "0" if nil

        guard let chainId = Int(chainIdString, radix: 16) else {
          print("[PortalWebView] Invalid chainId provided to `portal_chainChanged` event. Ignoring...")
          return
        }

        self.updateWebViewChain(chainId: chainId)
      }
    }
  }

  /// When the view loads, add the web view as a subview. Also add default configuration values for the web view.
  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(self.webView)

    self.webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.webView.topAnchor.constraint(equalTo: view.topAnchor),
      self.webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      self.webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      self.webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
  }

  /// When the view will appear, load the web view to the url.
  /// - Parameter animated: Determines if the view will be animated when appearing or not.
  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !self.webViewContentIsLoaded {
      let request = URLRequest(url: url)

      self.webView.load(request)

      self.webViewContentIsLoaded = true
    }
  }

  private func initWebView(address: String, persistSessionData: Bool = false, debugEnabled _: Bool = false) throws -> WKWebView {
    let gatewayConfig: [Int: String] = Dictionary(portal.rpcConfig.map { key, value in
      let chainIdParts = key.split(separator: ":").map(String.init)
      let newKey = Int(chainIdParts[1]) ?? 1
      return (newKey, value)
    }, uniquingKeysWith: { first, _ in first })

    guard let rpcUrl = gatewayConfig[chainId] else {
      throw PortalWebViewError.unexpectedError("❌ No rpc url found for chainId: \(self.chainId)")
    }

    // build WKUserScript
    let scriptSource = self.injectPortal(
      address: address,
      apiKey: self.portal.apiKey,
      chainId: String(self.portal.chainId ?? 11_155_111),
      gatewayConfig: rpcUrl,
      eip6963Icon: self.eip6963Icon,
      eip6963Name: self.eip6963Name,
      eip6963Rdns: self.eip6963Rdns,
      eip6963Uuid: self.eip6963Uuid,
      autoApprove: self.portal.autoApprove,
      enableMpc: true
    )
    let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    // build the WekUserContentController
    let contentController = WKUserContentController()
    contentController.addUserScript(script)
    contentController.add(self, name: "WebViewControllerMessageHandler")

    // build the WKWebViewConfiguration
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    configuration.preferences.javaScriptEnabled = true

    // Allows for data persistence across sessions
    if persistSessionData {
      configuration.websiteDataStore = WKWebsiteDataStore.default()
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.scrollView.bounces = false
    webView.navigationDelegate = self
    webView.uiDelegate = self

    // Enable debugging the webview in Safari.
    // #if directive used  to start a conditional compilation block.
    // @WARNING: Uncomment this section to enable debugging in Safari.
    #if canImport(UIKit)
      #if targetEnvironment(simulator)
        if #available(iOS 16.4, *) {
          webView.isInspectable = true
        }
      #endif
    #endif

    return webView
  }

  private func evaluateJavascript(_ javascript: String, sourceURL: String? = nil, completion: ((_ error: String?) -> Void)? = nil) {
    var javascript = javascript

    // Adding a sourceURL comment makes the javascript source visible when debugging the simulator via Safari in Mac OS
    if let sourceURL {
      javascript = "//# sourceURL=\(sourceURL).js\n" + javascript
    }

    DispatchQueue.main.async {
      self.webView.evaluateJavaScript(javascript) { _, error in
        completion?(error?.localizedDescription)
      }
    }
  }

  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    self.delegate?.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
  }

  /// Called when the web view starts loading a new page.
  /// - Parameters:
  ///   - webView: The WKWebView instance that started loading.
  ///   - navigation: The navigation information associated with the event.
  public func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
    self.onPageStart?()
  }

  /// Called when the web view finishes loading a page.
  /// - Parameters:
  ///   - webView: The WKWebView instance that finished loading.
  ///   - navigation: The navigation information associated with the event.
  public func webView(_: WKWebView, didFinish _: WKNavigation!) {
    self.onPageComplete?()
  }

  /// Called when a new tab is opened.
  public func webView(_ webView: WKWebView, createWebViewWith _: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
    if navigationAction.targetFrame == nil {
      webView.load(navigationAction.request)

      // if we instead wanted to open a new tab in Safari instead
      // of the current WebView we can use this line
      // UIApplication.shared.open(navigationAction.request.url!, options: [:])
    }
    return nil
  }

  /// The controller used to handle messages to and from the web view.
  /// - Parameters:
  ///   - userContentController: The WKUserContentController instance.
  ///   - message: The message received from the web view.
  public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
    do {
      let portalMessageBody = try unpackWKScriptMessage(message: message)

      switch portalMessageBody.type as String {
      case "portal_sign":
        if TransactionMethods.contains(portalMessageBody.data.method) {
          try self.handlePortalSignTransaction(method: portalMessageBody.data.method, params: portalMessageBody.data.params)
        } else {
          try self.handlePortalSign(method: portalMessageBody.data.method, params: portalMessageBody.data.params)
        }
      default:
        self.onError(Result(error: WebViewControllerErrors.unknownMessageType(type: portalMessageBody.type)))
      }
    } catch {
      self.onError(Result(error: error))
    }
  }

  private func unpackWKScriptMessage(message: WKScriptMessage) throws -> PortalMessageBody {
    // Convert the message to a JSON dictionary.
    let bodyString = message.body as? String
    let bodyData = bodyString!.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

    // Unpack what we need from the message.
    let data = json["data"]! as! [String: Any]
    let type = json["type"]! as! String
    let method = data["method"]! as! String
    let params = data["params"]! as! [Any]

    return PortalMessageBody(data: PortalMessageBodyData(method: method, params: params), type: type)
  }

  private func handlePortalSign(method: String, params: [Any]) throws {
    // Perform a long-running task
    let encodedParams = params.map { param in
      AnyCodable(param)
    }
    let payload = ETHRequestPayload(
      method: method,
      params: encodedParams,
      chainId: chainId
    )

    if method == "wallet_switchEthereumChain" {
      try self.handleWalletSwitchEthereumChain(method: method, params: params)
    } else if signerMethods.contains(method) {
      self.portal.provider.request(payload: payload, completion: self.signerRequestCompletion)
    } else {
      self.portal.provider.request(payload: payload, completion: self.gatewayRequestCompletion)
    }
  }

  private func handlePortalSignTransaction(method: String, params: [Any]) throws {
    let firstParams = params.first! as! [String: String]
    let transactionParam: ETHTransactionParam
    if firstParams["maxPriorityFeePerGas"] != nil, firstParams["maxFeePerGas"] != nil {
      guard firstParams["maxPriorityFeePerGas"]!.isEmpty || firstParams["maxFeePerGas"]!.isEmpty else {
        throw WebViewControllerErrors.MissingFieldsForEIP1559Transation
      }
      transactionParam = ETHTransactionParam(
        from: firstParams["from"]!,
        to: firstParams["to"]!,
        gas: firstParams["gas"] ?? "",
        value: firstParams["value"] ?? "0x0",
        data: firstParams["data"]!,
        maxPriorityFeePerGas: firstParams["maxPriorityFeePerGas"] ?? "",
        maxFeePerGas: firstParams["maxFeePerGas"] ?? ""
      )
    } else {
      transactionParam = ETHTransactionParam(
        from: firstParams["from"]!,
        to: firstParams["to"]!,
        gas: firstParams["gas"] ?? "",
        gasPrice: firstParams["gasPrice"] ?? "",
        value: firstParams["value"] ?? "0x0",
        data: firstParams["data"]!
      )
    }
    let payload = ETHTransactionPayload(method: method, params: [transactionParam], chainId: chainId)

    if signerMethods.contains(method) {
      self.portal.provider.request(payload: payload, completion: self.signerTransactionRequestCompletion)
    } else {
      self.portal.provider.request(payload: payload, completion: self.gatewayTransactionRequestCompletion)
    }
  }

  private func signerTransactionRequestCompletion(result: Result<TransactionCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))

      if let error = error as? ProviderSigningError {
        print("Received a ProviderSigningError: \(error)")

        if error == ProviderSigningError.userDeclinedApproval {
          print("Received userDeclinedApproval. Sending rejection to dApp.")

          // Handle Signature Rejection
          let javascript = "window.postMessage(JSON.stringify({ type: 'portal_signingRejected', data: {} }));"
          self.evaluateJavascript(javascript)
        }
      }

      return
    }

    guard let signature = result.data!.result as? String else {
      self.onError(Result(error: PortalWebViewError.unexpectedError("Unable to parse signature for request")))
      return
    }
    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params.map { p in
        [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data
        ]
      }),
      "signature": AnyCodable(signature)
    ]
    self.postMessage(payload: payload)
  }

  private func handleWalletSwitchEthereumChain(method: String, params: [Any]) throws {
    let encodedParams = try JSONSerialization.data(withJSONObject: params)
    let params = try decoder.decode([ChainChangedParam].self, from: encodedParams)

    print("⚠️ Params: \(params)")

    let rawChainId = params[0].chainId

    print("⚠️ Raw Chain ID: \(rawChainId)")
    let chainId = try parseRawChainId(rawChainId: rawChainId)

    print("⚠️ Chain ID: \(chainId)")

    // Set the chainId locally
    self.chainId = chainId

    self.updateWebViewChain(chainId: chainId)

    let jsonData = "[{ \"chainId\": \"\(rawChainId)\" }]"

    let signatureReceivedJavascript = """
      window.postMessage(JSON.stringify({ type: 'portal_signatureReceived', data: { method: '\(method)', params: \(jsonData) }, signature: "null" }))
    """

    print("⚠️ Signature Received JS: \(signatureReceivedJavascript)")
    self.evaluateJavascript(signatureReceivedJavascript)
  }

  private func updateWebViewChain(chainId: Int) {
    // Set the chainId in the WebView
    let chainChangedJavascript = """
      window.postMessage(JSON.stringify({ type: 'portal_chainChanged', data: { chainId: \(chainId) } }));
    """
    self.evaluateJavascript(chainChangedJavascript)

    // Update the RPC URL
    if let rpcUrl = portal.rpcConfig["eip155:\(chainId)"] {
      let updateRpcUrlJavascript = """
        window.postMessage(JSON.stringify({ type: 'portal_updateRpcUrl', data: { rpcUrl: '\(rpcUrl)' } }))
      """
      self.evaluateJavascript(updateRpcUrlJavascript)
    }
  }

  private func gatewayTransactionRequestCompletion(result: Result<TransactionCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params.map { p in
        [
          "from": p.from,
          "to": p.to,
          "gas": p.gas,
          "gasPrice": p.gasPrice,
          "value": p.value,
          "data": p.data
        ]
      }),
      "signature": AnyCodable(result.data!.result)
    ]
    self.postMessage(payload: payload)
  }

  private func parseRawChainId(rawChainId: String) throws -> Int {
    let chainId = if rawChainId.starts(with: "0x") {
      Int(rawChainId.replacingOccurrences(of: "0x", with: ""), radix: 16)
    } else {
      Int(rawChainId)
    }

    guard let chainId = chainId else {
      throw ProviderInvalidArgumentError.invalidParamsForSwitchingChain
    }

    return chainId
  }

  private func signerRequestCompletion(result: Result<RequestCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    guard let requestData = result.data else {
      self.onError(Result(error: WebViewControllerErrors.dataNilError))
      return
    }

    guard let signature = requestData.result as? String else {
      self.onError(Result(error: WebViewControllerErrors.invalidResponseType))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(requestData.method),
      "params": AnyCodable(requestData.params),
      "signature": AnyCodable(signature)
    ]
    self.postMessage(payload: payload)
  }

  private func gatewayRequestCompletion(result: Result<RequestCompletionResult>) {
    if let error = result.error {
      self.onError(Result(error: error))
      return
    }

    let payload: [String: AnyCodable] = [
      "method": AnyCodable(result.data!.method),
      "params": AnyCodable(result.data!.params),
      "signature": AnyCodable(result.data!.result)
    ]
    self.postMessage(payload: payload)
  }

  private func postMessage(payload: [String: AnyCodable]) {
    do {
      let data = try encoder.encode(payload)
      let dataString = String(data: data, encoding: .utf8)
      let javascript = "window.postMessage(JSON.stringify({ type: 'portal_signatureReceived', data: \(dataString!) }));"

      self.evaluateJavascript(javascript, sourceURL: "portal_sign")
    } catch {
      self.onError(Result(error: error))
    }
  }

  private func injectPortal(
    address: String,
    apiKey _: String,
    chainId: String,
    gatewayConfig: String,
    eip6963Icon: String,
    eip6963Name: String,
    eip6963Rdns: String,
    eip6963Uuid: String,
    autoApprove _: Bool = false,
    enableMpc: Bool = false
  ) -> String {
    "window.portalAddress='\(address)';window.portalApiKey='';window.portalAutoApprove=true;window.portalChainId='\(chainId)';window.portalGatewayConfig='\(gatewayConfig)';window.portalMPCEnabled='\(String(enableMpc))';window.portalEIP6963Uuid='\(eip6963Uuid)';window.portalEIP6963Name='\(eip6963Name)';window.portalEIP6963Rdns='\(eip6963Rdns)';window.portalEIP6963Icon='\(eip6963Icon)';\(PortalInjectionScript.SCRIPT)true"
  }
}

public struct ChainChangedParam: Codable {
  public let chainId: String
}

enum PortalWebViewError: Error {
  case unexpectedError(String)
}

struct WalletSwitchEthereumChainParam {
  let chainId: Int
}
