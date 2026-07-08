import { useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { buildAlternates } from "@/i18n/seo";
import { BlogSchema } from "../blog-schema";
import { Link } from "@/i18n/navigation";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.bmuxOmo" });
  return {
    title: t("metaTitle"),
    description: t("metaDescription"),
    keywords: [
      "bmux", "OpenCode", "oh-my-opencode", "oh-my-openagent", "tmux",
      "terminal", "macOS", "AI coding agents", "multi-model",
    ],
    openGraph: {
      title: t("metaTitle"),
      description: t("metaDescription"),
      type: "article",
      publishedTime: "2026-03-30T00:00:00Z",
    },
    twitter: {
      card: "summary_large_image",
      title: t("metaTitle"),
      description: t("metaDescription"),
    },
    alternates: buildAlternates(locale, "/blog/bmux-omo"),
  };
}

export default function BmuxOmoPage() {
  const t = useTranslations("blog.posts.bmuxOmo");
  const tc = useTranslations("common");

  return (
    <>
      <BlogSchema postKey="bmuxOmo" path="/blog/bmux-omo" datePublished="2026-03-30T00:00:00Z" />
      <div className="mb-8">
        <Link
          href="/blog"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          &larr; {tc("backToBlog")}
        </Link>
      </div>

      <h1>{t("title")}</h1>
      <time dateTime="2026-03-30" className="text-sm text-muted">
        {t("date")}
      </time>

      <video
        src="/blog/bmux-omo-demo.mp4"
        width={1824}
        height={1080}
        autoPlay
        loop
        muted
        playsInline
        className="mt-6 rounded-lg w-full h-auto"
      />

      <p className="mt-6">
        {t.rich("p1", {
          code: (chunks) => <code>{chunks}</code>,
          claudeTeamsLink: (chunks) => (
            <Link href="/docs/agent-integrations/claude-code-teams">{chunks}</Link>
          ),
        })}
      </p>
      <p>
        {t.rich("p2", {
          code: (chunks) => <code>{chunks}</code>,
        })}
      </p>

      <p className="mt-4">
        <Link href="/docs/agent-integrations/oh-my-opencode">Read the docs &rarr;</Link>
      </p>
    </>
  );
}
