# Recruitr

This folder contains a sanitized public demo variant of the production Recruitr app. It was derived from a working internal macOS application, but all sensitive credentials, private infrastructure identifiers, and production webhook destinations were removed. The GitHub variant is intentionally configured to run in local demo mode, with seeded sample data and mock AI outputs so the project can be shared safely.

## Public Demo Notes

- The app in this folder is named `Recruitr`.
- Sensitive configuration values were replaced with placeholders such as `YOUR_OPENAI_API_KEY`, `YOUR_GEMINI_API_KEY`, and `YOUR_APPWRITE_PROJECT_ID`.
- The GitHub variant does not connect to the production backend. Records, prompts, and prompt bundles run in a local demo store.
- Large local Whisper model binaries were intentionally omitted from this public copy. If you want real local transcription in a private build, you would need to add those model assets back separately.
- The original `WarrenRecruitingAI` app outside this folder was intentionally left unchanged.

## Inspiration

Recruitr was inspired by a real problem we saw while helping a recruiting business with its workflow. Recruiters were spending too much time turning candidate calls, client calls, and CVs into summaries, emails, and posts instead of focusing on relationships and placements. We wanted to build something that could remove that repetitive work and make their process faster and more professional. That led to Recruitr, an AI-powered tool built to support recruiters in the parts of the job that take the most manual effort.

## What it does

Recruitr lets recruiters upload audio calls and CVs, then generates a summary of the candidate they spoke with. It can also draft an email that can be sent to clients and create posts that recruiters can use wherever they need to present a candidate. On the client side, it can summarize client calls and generate LinkedIn-style posts or requirement write-ups to help attract the right candidates. Overall, the app turns raw recruiting information into polished, ready-to-use content.

## How we built it

We built Recruitr in Swift. A major part of the project was figuring out how to combine the app interface with AI in a way that produced useful recruiting outputs rather than just generic summaries. We designed the workflow around the actual tasks recruiters do: uploading calls and CVs, reviewing generated summaries, and using drafted content for outreach and sourcing. Much of the build involved iterating on how to make the outputs both practical and affordable for real users, while interfacing with real recruiting companies to do so.

## Challenges we ran into

One of the biggest challenges was that we had to learn Swift for the first time while building the app. That meant we were simultaneously learning a new language, solving app-development problems, and trying to make the product actually useful. Another challenge was figuring out the best and cheapest way to have this offer create the best product possible so that we could release it to recruiters for lower prices than most alternatives, such as using ChatGPT, while also obtaining better results.

## Accomplishments that we're proud of

One of our biggest accomplishments is that Recruitr is already being used in the real world. It is now used full-time by MS Legal and has also been implemented at other firms, showing that the product solves a genuine workflow problem beyond just one team. On average, it saves about one hour per employee per day of secretarial and administrative work, which translates into meaningful time savings and higher productivity. We are especially proud that Recruitr has moved beyond being just an idea and has become a tool that organizations rely on in their daily operations.

## What we learned

We learned that building good software is not just about writing code; it is about solving real user problems under real constraints. We learned Swift, but we also learned how much product development depends on iteration, debugging, and fast self-teaching. We learned that AI is most useful when it is applied to specific workflows with clear outcomes, not when it is added just for the sake of it. We also learned how important cost, usability, and output quality are when designing tools for businesses.

## What's next for Recruitr

Now that Recruitr is already being used full-time by MS Legal and has been implemented in other firms, our next focus is scaling and refining the product based on real user feedback. We want to improve the quality and personalization of its summaries, emails, and posts so that they feel even more polished, accurate, and tailored to each firm’s workflow. We also plan to expand Recruitr’s capabilities across additional administrative and recruiting tasks, helping teams save even more time each day. Long term, our goal is for Recruitr to become an essential AI assistant for firms and recruiters by reducing repetitive work and letting professionals focus on higher-value client and candidate relationships.
